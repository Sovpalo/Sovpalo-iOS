import Foundation

protocol CreateMeetingBusinessLogic {
    func createMeeting(request: CreateMeetingRequest)
}

struct CreateMeetingRequest {
    let title: String
    let date: Date
    let time: Date
    let address: String
    let description: String
}

final class CreateMeetingInteractor: CreateMeetingBusinessLogic {
    private let company: Company

    var presenter: CreateMeetingPresenterProtocol?
    var worker: CreateMeetingWorkerProtocol?

    init(company: Company) {
        self.company = company
    }

    func createMeeting(request: CreateMeetingRequest) {
        let trimmedTitle = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            presenter?.presentError(message: "Введите место встречи")
            return
        }

        guard let startDate = combine(date: request.date, time: request.time) else {
            presenter?.presentError(message: "Не удалось собрать дату встречи")
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
            endTime: nil,
            companyId: company.id
        )

        Task {
            do {
                try await worker?.createMeeting(companyId: company.id, payload: payload)
                await MainActor.run {
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
