import Foundation

protocol CreateMeetingBusinessLogic {
    func createMeeting(request: CreateMeetingRequest)
}

struct CreateMeetingRequest {
    let title: String
    let startDate: Date
    let endDate: Date
    let startTime: Date
    let endTime: Date
    let address: String
    let description: String
    let photo: CreateMeetingPhotoUpload?
}

final class CreateMeetingInteractor: CreateMeetingBusinessLogic {
    private let company: Company

    var presenter: CreateMeetingPresenterProtocol?
    var worker: CreateMeetingWorkerProtocol?

    init(company: Company) {
        self.company = company
    }

    func createMeeting(request: CreateMeetingRequest) {
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

        let finalDescription = makeDescription(
            address: request.address,
            description: request.description
        )

        let payload = CreateMeetingPayload(
            title: trimmedTitle,
            description: finalDescription,
            startTime: Self.isoFormatter.string(from: startDate),
            endTime: Self.isoFormatter.string(from: endDate),
            companyId: company.id
        )

        Task {
            do {
                try await worker.createMeeting(payload: payload, photo: request.photo)
                await MainActor.run {
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.meetingCreated,
                        parameters: [
                            "screen": "CreateMeeting",
                            "company_id": self.company.id,
                            "has_address": !request.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            "has_description": !request.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            "has_photo": request.photo != nil
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
}
