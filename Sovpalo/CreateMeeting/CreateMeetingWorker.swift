import Foundation

struct CreateMeetingPayload: Encodable {
    let title: String
    let description: String?
    let startTime: String
    let endTime: String?
    let companyId: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case startTime = "start_time"
        case endTime = "end_time"
        case companyId = "company_id"
    }
}

enum CreateMeetingWorkerError: LocalizedError {
    case invalidURL
    case tokenNotFound
    case tokenDecodingFailed
    case badServerResponse
    case badStatus(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL запроса"
        case .tokenNotFound:
            return "Не найден токен авторизации"
        case .tokenDecodingFailed:
            return "Не удалось прочитать токен авторизации"
        case .badServerResponse:
            return "Некорректный ответ сервера"
        case let .badStatus(code, message):
            return "Ошибка создания встречи (\(code)): \(message)"
        }
    }
}

protocol CreateMeetingWorkerProtocol {
    func createMeeting(companyId: Int, payload: CreateMeetingPayload) async throws
}

final class CreateMeetingWorker: CreateMeetingWorkerProtocol {
    private let keychain: KeychainLogic

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func createMeeting(companyId: Int, payload: CreateMeetingPayload) async throws {
        guard let url = URL(string: "http://localhost:8000/companies/\(companyId)/events") else {
            throw CreateMeetingWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw CreateMeetingWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw CreateMeetingWorkerError.tokenDecodingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CreateMeetingWorkerError.badServerResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw CreateMeetingWorkerError.badStatus(code: httpResponse.statusCode, message: serverMessage)
        }
    }
}
