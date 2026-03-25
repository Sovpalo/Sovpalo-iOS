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

    init(company: Company) {
        self.company = company
    }

    func loadMeetings() {
        guard let worker else {
            presenter?.presentError("Worker is unavailable")
            return
        }

        Task {
            do {
                let eventDTOs = try await worker.fetchCompanyEvents(companyId: company.id)
                print("eventDTOs count =", eventDTOs.count)

                var mappedMeetings: [Meeting] = []

                for dto in eventDTOs {
                    print("loading summary for event id =", dto.id)
                    let summary = try await worker.fetchAttendanceSummary(companyId: company.id, eventId: dto.id)
                    let meeting = mapMeeting(dto: dto, summary: summary)
                    mappedMeetings.append(meeting)
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

        localStatuses[eventId] = status

        Task {
            do {
                try await worker.setAttendance(companyId: company.id, eventId: eventId, status: backendStatus)
                presenter?.presentAttendanceUpdated(for: eventId, status: status)
                loadMeetings()
            } catch {
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

    private func mapMeeting(dto: CompanyEventDTO, summary: EventAttendanceSummaryDTO) -> Meeting {
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
            responseStatus: localStatuses[dto.id] ?? .none,
            isArchived: isArchived
        )
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
