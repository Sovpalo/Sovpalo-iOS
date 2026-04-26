//
//  EditMeetingInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 25.03.2026.
//

import Foundation
import UIKit

protocol EditMeetingBusinessLogic {
    func loadInitialData()
    func updateMeeting(request: EditMeetingRequest)
    func loadMeetingImage(from photoURL: String, targetSize: CGSize) async -> UIImage?
}

struct EditMeetingRequest {
    let title: String
    let startDate: Date
    let endDate: Date
    let startTime: Date
    let endTime: Date
    let address: String
    let description: String
    let photo: EditMeetingPhotoUpload?
    let shouldRemovePhoto: Bool
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
            startDateText: Self.dateFormatter.string(from: initialData.startDate),
            endDateText: Self.dateFormatter.string(from: initialData.endDate),
            startTimeText: Self.timeFormatter.string(from: initialData.startDate),
            endTimeText: Self.timeFormatter.string(from: initialData.endDate),
            address: initialData.address,
            description: initialData.description,
            startDate: initialData.startDate,
            endDate: initialData.endDate,
            photoURL: initialData.photoURL
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

        guard let startDate = combine(date: request.startDate, time: request.startTime) else {
            presenter?.presentError(message: "Не удалось собрать дату начала встречи")
            return
        }

        guard let endDate = combine(date: request.endDate, time: request.endTime) else {
            presenter?.presentError(message: "Не удалось собрать дату окончания встречи")
            return
        }

        guard startDate < endDate else {
            presenter?.presentError(message: "Время окончания должно быть позже времени начала")
            return
        }

        let payload = EditMeetingPayload(
            title: trimmedTitle,
            description: makeDescription(address: request.address, description: request.description),
            startTime: Self.isoFormatter.string(from: startDate),
            endTime: Self.isoFormatter.string(from: endDate),
            companyId: initialData.companyId,
            shouldRemovePhoto: request.shouldRemovePhoto
        )

        Task {
            do {
                try await worker.updateMeeting(
                    eventId: initialData.eventId,
                    payload: payload,
                    photo: request.photo
                )
                await MainActor.run {
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.meetingUpdated,
                        parameters: [
                            "screen": "EditMeeting",
                            "company_id": self.initialData.companyId,
                            "meeting_id": self.initialData.eventId,
                            "has_address": !request.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            "has_description": !request.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            "has_photo": request.photo != nil || (!request.shouldRemovePhoto && self.initialData.photoURL != nil)
                        ]
                    )
                    self.presenter?.presentSuccess()
                }
            } catch {
                await MainActor.run {
                    self.presenter?.presentError(message: error.localizedDescription)
                }
            }
        }
    }

    func loadMeetingImage(from photoURL: String, targetSize: CGSize) async -> UIImage? {
        guard let worker else { return nil }
        return await worker.fetchImage(from: photoURL, targetSize: targetSize)
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
