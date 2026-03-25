//
//  InfoMeetingInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 24.03.2026.
//

import Foundation

protocol InfoMeetingBusinessLogic {
    func loadMeeting()
    func didTapEdit()
    func deleteMeeting()
}

final class InfoMeetingInteractor: InfoMeetingBusinessLogic {
    var presenter: InfoMeetingPresenterProtocol?
    var worker: InfoMeetingWorkerProtocol?

    private let companyId: Int
    private let meetingId: Int
    private let initialMeeting: Meeting?
    private var editInitialData: EditMeetingInitialData?

    init(companyId: Int, meetingId: Int, initialMeeting: Meeting?) {
        self.companyId = companyId
        self.meetingId = meetingId
        self.initialMeeting = initialMeeting
    }

    func loadMeeting() {
        if let initialMeeting {
            presenter?.presentMeeting(makeViewModel(from: initialMeeting))
        }

        guard let worker else {
            presenter?.presentError("Worker is unavailable")
            return
        }

        Task {
            do {
                async let eventDTO = worker.fetchCompanyEvent(companyId: companyId, eventId: meetingId)
                async let summaryDTO = worker.fetchAttendanceSummary(companyId: companyId, eventId: meetingId)

                let (event, summary) = try await (eventDTO, summaryDTO)
                let meeting = mapMeeting(dto: event, summary: summary)
                editInitialData = makeEditInitialData(from: event)
                presenter?.presentMeeting(makeViewModel(from: meeting))
            } catch {
                presenter?.presentError(error.localizedDescription)
            }
        }
    }

    func didTapEdit() {
        guard let editInitialData else {
            presenter?.presentError("Данные встречи еще загружаются")
            return
        }

        presenter?.routeToEditMeeting(initialData: editInitialData)
    }
    
    func deleteMeeting() {
        guard let worker else {
            presenter?.presentError("Worker is unavailable")
            return
        }

        Task {
            do {
                try await worker.deleteEvent(eventId: meetingId)
                presenter?.routeBackAfterDelete()
            } catch {
                presenter?.presentError(error.localizedDescription)
            }
        }
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
            responseStatus: .none,
            isArchived: false
        )
    }

    private func makeViewModel(from meeting: Meeting) -> InfoMeetingViewModel {
        let locationText: String = {
            if meeting.cityText.isEmpty { return meeting.addressText }
            return "\(meeting.cityText), \(meeting.addressText)"
        }()

        let titleText = [meeting.title, meeting.dateText]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0 != "—" }
            .joined(separator: " ")

        let descriptionText = meeting.descriptionText?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return InfoMeetingViewModel(
            title: titleText.isEmpty ? meeting.title : titleText,
            timeText: meeting.timeText,
            locationText: locationText.isEmpty ? "Адрес не указан" : locationText,
            goingPeople: meeting.attendeesGoing,
            notGoingPeople: meeting.attendeesNotGoing,
            descriptionText: (descriptionText?.isEmpty == false) ? descriptionText! : "Описание отсутствует"
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

    private func makeEditInitialData(from dto: CompanyEventDTO) -> EditMeetingInitialData? {
        guard let startTime = dto.startTime else { return nil }
        guard let startDate = Self.isoParserWithFractional.date(from: startTime) ?? Self.isoParser.date(from: startTime) else {
            return nil
        }

        let parsedDescription = splitDescription(dto.description)

        return EditMeetingInitialData(
            companyId: companyId,
            eventId: dto.id,
            title: dto.title,
            startDate: startDate,
            address: parsedDescription.address == "Адрес не указан" ? "" : parsedDescription.address,
            description: parsedDescription.details ?? ""
        )
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
