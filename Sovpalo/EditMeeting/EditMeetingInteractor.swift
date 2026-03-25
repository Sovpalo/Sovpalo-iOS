//
//  EditMeetingInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 25.03.2026.
//

import Foundation

protocol EditMeetingBusinessLogic {
    func loadInitialData()
    func updateMeeting(request: EditMeetingRequest)
}

struct EditMeetingRequest {
    let title: String
    let date: Date
    let time: Date
    let address: String
    let description: String
}

final class EditMeetingInteractor: EditMeetingBusinessLogic {
    var presenter: EditMeetingPresenterProtocol?
    var worker: EditMeetingWorkerProtocol?

    private let initialData: EditMeetingInitialData

    init(initialData: EditMeetingInitialData) {
        self.initialData = initialData
    }

    func loadInitialData() {
        let viewModel = EditMeetingPrefillViewModel(
            title: initialData.title,
            dateText: Self.dateFormatter.string(from: initialData.startDate),
            timeText: Self.timeFormatter.string(from: initialData.startDate),
            address: initialData.address,
            description: initialData.description,
            startDate: initialData.startDate
        )

        presenter?.presentInitialData(viewModel)
    }

    func updateMeeting(request: EditMeetingRequest) {
        guard let worker else {
            presenter?.presentError(message: "Worker is unavailable")
            return
        }

        let trimmedTitle = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            presenter?.presentError(message: "Введите место встречи")
            return
        }

        guard let startDate = combine(date: request.date, time: request.time) else {
            presenter?.presentError(message: "Не удалось собрать дату встречи")
            return
        }

        let payload = EditMeetingPayload(
            title: trimmedTitle,
            description: makeDescription(address: request.address, description: request.description),
            startTime: Self.isoFormatter.string(from: startDate),
            endTime: nil,
            companyId: initialData.companyId
        )

        Task {
            do {
                try await worker.updateMeeting(eventId: initialData.eventId, payload: payload)
                presenter?.presentSuccess()
            } catch {
                presenter?.presentError(message: error.localizedDescription)
            }
        }
    }

    private func combine(date: Date, time: Date) -> Date? {
        let calendar = Calendar.current

        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var components = DateComponents()
        components.year = dateComponents.year
        components.month = dateComponents.month
        components.day = dateComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute

        return calendar.date(from: components)
    }

    private func makeDescription(address: String, description: String) -> String? {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedAddress.isEmpty && !trimmedDescription.isEmpty {
            return "Адрес: \(trimmedAddress)\n\n\(trimmedDescription)"
        }

        if !trimmedAddress.isEmpty {
            return "Адрес: \(trimmedAddress)"
        }

        if !trimmedDescription.isEmpty {
            return trimmedDescription
        }

        return nil
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
