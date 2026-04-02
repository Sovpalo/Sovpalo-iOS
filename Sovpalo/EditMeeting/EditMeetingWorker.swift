//
//  EditMeetingWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 25.03.2026.
//

import Foundation

struct EditMeetingPayload: Encodable {
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

enum EditMeetingWorkerError: LocalizedError {
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
            return "Ошибка изменения встречи (\(code)): \(message)"
        }
    }
}

protocol EditMeetingWorkerProtocol {
    func updateMeeting(eventId: Int, payload: EditMeetingPayload) async throws
}

final class EditMeetingWorker: EditMeetingWorkerProtocol {
    private let keychain: KeychainLogic

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func updateMeeting(eventId: Int, payload: EditMeetingPayload) async throws {
        guard let url = URL(string: Server.url + "/events/\(eventId)") else {
            throw EditMeetingWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw EditMeetingWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw EditMeetingWorkerError.tokenDecodingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EditMeetingWorkerError.badServerResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw EditMeetingWorkerError.badStatus(code: httpResponse.statusCode, message: serverMessage)
        }
    }
}
