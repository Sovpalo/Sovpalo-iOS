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

        Task {
            do {
                let username = try await fetchCurrentUsername()
                currentUsername = username
                let eventDTOs = try await worker.fetchCompanyEvents(companyId: company.id)
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

                presenter?.presentMeetings(mappedMeetings)
            } catch {
                print("LOAD MEETINGS ERROR =", error)
                presenter?.presentError(error.localizedDescription)
            }
        }
    }
    func setAttendance(eventId: Int, status: MeetingResponseStatus) {
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

        let previousStatus = localStatuses[eventId] ?? .none
        localStatuses[eventId] = status
        presenter?.presentAttendanceUpdated(for: eventId, status: status)

        Task {
            do {
                try await worker.setAttendance(companyId: company.id, eventId: eventId, status: backendStatus)
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
                loadMeetings()
            } catch {
                localStatuses[eventId] = previousStatus
                presenter?.presentAttendanceUpdated(for: eventId, status: previousStatus)
                presenter?.presentError(error.localizedDescription)
            }
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
