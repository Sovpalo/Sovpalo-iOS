//
//  CreateIdeasWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import Foundation

struct CreateIdeaPayload: Encodable {
    let title: String
    let description: String?
}

enum CreateIdeasWorkerError: LocalizedError {
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
            return "Ошибка создания идеи (\(code)): \(message)"
        }
    }
}

protocol CreateIdeasWorkerProtocol {
    func createIdea(companyId: Int, payload: CreateIdeaPayload) async throws
}

final class CreateIdeasWorker: CreateIdeasWorkerProtocol {
    private let keychain: KeychainLogic
    private let baseURL: String = "http://localhost:8000"

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func createIdea(companyId: Int, payload: CreateIdeaPayload) async throws {
        guard let url = URL(string: baseURL + "/companies/\(companyId)/ideas") else {
            throw CreateIdeasWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw CreateIdeasWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw CreateIdeasWorkerError.tokenDecodingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CreateIdeasWorkerError.badServerResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw CreateIdeasWorkerError.badStatus(code: httpResponse.statusCode, message: serverMessage)
        }
    }
}
