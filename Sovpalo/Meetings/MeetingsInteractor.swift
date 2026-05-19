import Foundation

protocol MeetingsBusinessLogic {
    func loadMeetings()
    func setAttendance(eventId: Int, status: MeetingResponseStatus)
    func selectMeeting(_ meeting: Meeting)
}

final class MeetingsInteractor: MeetingsBusinessLogic {
    let company: Company

    var presenter: MeetingsPresenterProtocol?
    var worker: MeetingsWorkerProtocol?
    private var localStatuses: [Int: MeetingResponseStatus] = [:]
    private var knownStatuses: [Int: MeetingResponseStatus] = [:]
    private var pendingAttendanceEventIds: Set<Int> = []
    private var loadGeneration = 0
    private var suppressCachedMeetingsUntil: Date?
    private let keychain: KeychainLogic
    private let profileWorker: FirstGroupWorkerProtocol
    private var currentUsername: String?

    init(
        company: Company,
        keychain: KeychainLogic = KeychainService(),
        profileWorker: FirstGroupWorkerProtocol = FirstGroupWorker()
    ) {
        self.company = company
        self.keychain = keychain
        self.profileWorker = profileWorker
    }

    func loadMeetings() {
        guard let worker else {
            presenter?.presentError("Worker is unavailable")
            return
        }

        loadGeneration += 1
        let generation = loadGeneration
        presenter?.presentLoading(true)
        Task {
            let shouldShowCachedMeetings = shouldShowCachedMeetings()
            let cachedMeetings = applyLocalAttendanceOverrides(
                to: LocalCacheService.shared.fetchMeetings(companyId: company.id)
            )
            updateKnownStatuses(from: cachedMeetings)
            var didShowCachedMeetings = false
            if shouldShowCachedMeetings, generation == loadGeneration, !cachedMeetings.isEmpty {
                didShowCachedMeetings = true
                presenter?.presentOfflineMode(true)
                presenter?.presentMeetings(cachedMeetings)
            }

            do {
                let username = try await fetchCurrentUsername()
                currentUsername = username
                let eventDTOs = try await worker.fetchCompanyEvents(companyId: company.id)
                LocalCacheService.shared.saveCompanyEvents(eventDTOs, companyId: company.id)
                print("eventDTOs count =", eventDTOs.count)
                print(">>> Events from server:", eventDTOs.map { $0.id })

                var mappedMeetings: [Meeting] = []

                for dto in eventDTOs {
                    do {
                        let summary = try await worker.fetchAttendanceSummary(companyId: company.id, eventId: dto.id)
                        let meeting = mapMeeting(dto: dto, summary: summary, currentUsername: username)
                        mappedMeetings.append(meeting)
                    } catch {
                        print("Skipping event \(dto.id), summary failed: \(error)")
                    }
                }

                mappedMeetings.sort { lhs, rhs in
                    lhs.id > rhs.id
                }
                mappedMeetings = applyLocalAttendanceOverrides(to: mappedMeetings)
                updateKnownStatuses(from: mappedMeetings)

                guard generation == loadGeneration else { return }
                presenter?.presentLoading(false)
                presenter?.presentOfflineMode(false)
                LocalCacheService.shared.saveMeetings(mappedMeetings, companyId: company.id)
                presenter?.presentMeetings(mappedMeetings)
            } catch {
                print("LOAD MEETINGS ERROR =", error)
                guard generation == loadGeneration else { return }
                presenter?.presentLoading(false)
                if didShowCachedMeetings {
                    presenter?.presentOfflineMode(true)
                } else {
                    presenter?.presentOfflineMode(false)
                    presenter?.presentError(error.localizedDescription)
                }
            }
        }
    }
    func setAttendance(eventId: Int, status: MeetingResponseStatus) {
        guard !pendingAttendanceEventIds.contains(eventId) else {
            return
        }

        guard let worker else {
            presenter?.presentError("Worker is unavailable")
            return
        }

        let backendStatus: String
        switch status {
        case .none:
            backendStatus = "unknown"
        case .going:
            backendStatus = "going"
        case .notGoing:
            backendStatus = "not_going"
        case .createdByMe:
            backendStatus = "unknown"
        }

        let previousStatus = localStatuses[eventId] ?? knownStatuses[eventId] ?? .none
        let displayUsername = currentDisplayUsername()
        loadGeneration += 1
        suppressCachedMeetingsUntil = Date().addingTimeInterval(6)
        pendingAttendanceEventIds.insert(eventId)
        localStatuses[eventId] = status
        knownStatuses[eventId] = status
        presenter?.presentAttendanceUpdated(for: eventId, status: status, currentUsername: displayUsername)

        Task {
            do {
                try await worker.setAttendance(companyId: company.id, eventId: eventId, status: backendStatus)
                let summary = try? await worker.fetchAttendanceSummary(companyId: company.id, eventId: eventId)
                await MainActor.run {
                    AppMetricaService.reportEvent(
                        self.appMetricaEventName(for: status),
                        parameters: [
                            "screen": "Meetings",
                            "company_id": self.company.id,
                            "meeting_id": eventId
                        ]
                    )
                }

                pendingAttendanceEventIds.remove(eventId)
                knownStatuses[eventId] = status
                if let summary {
                    presenter?.presentAttendanceSummaryUpdated(
                        for: eventId,
                        status: status,
                        attendeesGoing: summary.going,
                        attendeesNotGoing: summary.notGoing,
                        currentUsername: displayUsername
                    )
                }
            } catch {
                pendingAttendanceEventIds.remove(eventId)
                localStatuses[eventId] = previousStatus
                knownStatuses[eventId] = previousStatus
                presenter?.presentAttendanceUpdated(for: eventId, status: previousStatus, currentUsername: displayUsername)
                presenter?.presentError(error.localizedDescription)
            }
        }
    }

    private func shouldShowCachedMeetings() -> Bool {
        guard let suppressCachedMeetingsUntil else {
            return true
        }
        return Date() >= suppressCachedMeetingsUntil
    }

    private func applyLocalAttendanceOverrides(to meetings: [Meeting]) -> [Meeting] {
        meetings.map { meeting in
            guard let status = localStatuses[meeting.id] else {
                return meeting
            }

            return meetingWithLocalStatus(meeting, status: status)
        }
    }

    private func meetingWithLocalStatus(_ meeting: Meeting, status: MeetingResponseStatus) -> Meeting {
        let displayUsername = currentDisplayUsername()
        let normalizedUsername = displayUsername?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let filteredGoing = meeting.attendeesGoing.filter { attendee in
            guard let normalizedUsername else { return true }
            return attendee.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != normalizedUsername
        }
        let filteredNotGoing = meeting.attendeesNotGoing.filter { attendee in
            guard let normalizedUsername else { return true }
            return attendee.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != normalizedUsername
        }

        let trimmedDisplayUsername = displayUsername?.trimmingCharacters(in: .whitespacesAndNewlines)
        let attendeesGoing: [String]
        let attendeesNotGoing: [String]

        switch status {
        case .going:
            attendeesGoing = appendDisplayUsernameIfNeeded(to: filteredGoing, displayUsername: trimmedDisplayUsername)
            attendeesNotGoing = filteredNotGoing
        case .notGoing:
            attendeesGoing = filteredGoing
            attendeesNotGoing = appendDisplayUsernameIfNeeded(to: filteredNotGoing, displayUsername: trimmedDisplayUsername)
        case .none, .createdByMe:
            attendeesGoing = filteredGoing
            attendeesNotGoing = filteredNotGoing
        }

        return Meeting(
            id: meeting.id,
            title: meeting.title,
            dateText: meeting.dateText,
            timeText: meeting.timeText,
            cityText: meeting.cityText,
            addressText: meeting.addressText,
            descriptionText: meeting.descriptionText,
            photoURL: meeting.photoURL,
            attendeesGoing: attendeesGoing,
            attendeesNotGoing: attendeesNotGoing,
            organizerName: meeting.organizerName,
            responseStatus: status,
            isArchived: meeting.isArchived
        )
    }

    private func appendDisplayUsernameIfNeeded(to attendees: [String], displayUsername: String?) -> [String] {
        guard let displayUsername, !displayUsername.isEmpty else {
            return attendees
        }

        let normalizedDisplayUsername = displayUsername.lowercased()
        guard !attendees.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedDisplayUsername }) else {
            return attendees
        }

        return attendees + [displayUsername]
    }

    private func currentDisplayUsername() -> String? {
        if let currentUsername, !currentUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return currentUsername
        }
        return LocalCacheService.shared.fetchSettingsProfile()?.username
    }

    private func updateKnownStatuses(from meetings: [Meeting]) {
        for meeting in meetings {
            knownStatuses[meeting.id] = meeting.responseStatus
        }
    }

    func selectMeeting(_ meeting: Meeting) {
        presenter?.routeToMeetingInfo(
            companyId: company.id,
            meetingId: meeting.id,
            initialMeeting: meeting
        )
    }

    private func mapMeeting(
        dto: CompanyEventDTO,
        summary: EventAttendanceSummaryDTO,
        currentUsername: String
    ) -> Meeting {
        let startDate = dto.startTime.flatMap {
            Self.isoParserWithFractional.date(from: $0) ?? Self.isoParser.date(from: $0)
        }

        let endDate = dto.endTime.flatMap {
            Self.isoParserWithFractional.date(from: $0) ?? Self.isoParser.date(from: $0)
        }

        let dateText = startDate.map { Self.dateFormatter.string(from: $0) } ?? "—"
        let timeText: String = {
            guard let startDate else { return "—" }
            let start = Self.timeFormatter.string(from: startDate)
            if let endDate {
                let end = Self.timeFormatter.string(from: endDate)
                return "\(start)-\(end)"
            }
            return start
        }()

        let isArchived: Bool = {
            guard let startDate else { return false }
            return startDate < Date()
        }()

        let parsedDescription = splitDescription(dto.description)

        let serverStatus = attendanceStatus(from: summary, currentUsername: currentUsername)

        return Meeting(
            id: dto.id,
            title: dto.title,
            dateText: dateText,
            timeText: timeText,
            cityText: "",
            addressText: parsedDescription.address,
            descriptionText: parsedDescription.details,
            photoURL: dto.photoURL,
            attendeesGoing: summary.going,
            attendeesNotGoing: summary.notGoing,
            organizerName: nil,
            responseStatus: localStatuses[dto.id] ?? serverStatus,
            isArchived: isArchived
        )
    }

    private func attendanceStatus(
        from summary: EventAttendanceSummaryDTO,
        currentUsername: String
    ) -> MeetingResponseStatus {
        let normalizedUsername = currentUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if summary.going.contains(where: { $0.lowercased() == normalizedUsername }) {
            return .going
        }

        if summary.notGoing.contains(where: { $0.lowercased() == normalizedUsername }) {
            return .notGoing
        }

        return .none
    }

    private func fetchCurrentUsername() async throws -> String {
        if let currentUsername, !currentUsername.isEmpty {
            return currentUsername
        }

        guard let tokenData = keychain.getData(forKey: "auth.token"),
              let token = String(data: tokenData, encoding: .utf8),
              !token.isEmpty else {
            throw MeetingsWorkerError.tokenNotFound
        }

        return try await profileWorker.getCurrentUsername(token: token)
    }

    private func splitDescription(_ description: String?) -> (address: String, details: String?) {
        guard let description else {
            return ("Адрес не указан", nil)
        }

        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ("Адрес не указан", nil)
        }

        let parts = trimmed.components(separatedBy: "\n\n")
        if let first = parts.first, first.hasPrefix("Адрес:") {
            let address = first.replacingOccurrences(of: "Адрес:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let details = parts.dropFirst().joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                address.isEmpty ? "Адрес не указан" : address,
                details.isEmpty ? nil : details
            )
        }

        return ("Адрес не указан", trimmed)
    }

    private func appMetricaEventName(for status: MeetingResponseStatus) -> String {
        switch status {
        case .going:
            return AppMetricaEvent.meetingAttendanceGoing
        case .notGoing:
            return AppMetricaEvent.meetingAttendanceNotGoing
        case .none, .createdByMe:
            return AppMetricaEvent.meetingAttendanceCanceled
        }
    }

    private static let isoParserWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
