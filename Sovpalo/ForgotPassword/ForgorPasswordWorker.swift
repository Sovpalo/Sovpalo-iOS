//
//  ForgorPasswordWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol ForgorPasswordWorkerProtocol {
    func requestPasswordReset(email: String) async throws
}

private struct ForgotPasswordRequestBody: Encodable {
    let email: String
}

private struct ForgotPasswordResponseBody: Decodable {
    let message: String?
    let expiresInSec: Int?
}

enum ForgotPasswordWorkerError: LocalizedError {
    case invalidURL
    case invalidResponse
    case badStatus(code: Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL"
        case .invalidResponse:
            return "Некорректный ответ сервера"
        case .badStatus(let code):
            return "Ошибка сервера. Код: \(code)"
        case .decodingFailed:
            return "Не удалось прочитать ответ сервера"
        }
    }
}

final class ForgorPasswordWorker: ForgorPasswordWorkerProtocol {
    private let baseURL: URL?
    private let session: URLSession

    init(
        baseURL: URL? = URL(string: "http://localhost:8000"),
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func requestPasswordReset(email: String) async throws {
        guard let baseURL else {
            throw ForgotPasswordWorkerError.invalidURL
        }

        let endpoint = baseURL.appendingPathComponent("/auth/password/forgot")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ForgotPasswordRequestBody(email: email))

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ForgotPasswordWorkerError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ForgotPasswordWorkerError.badStatus(code: httpResponse.statusCode)
        }

        if !data.isEmpty {
            do {
                _ = try JSONDecoder().decode(ForgotPasswordResponseBody.self, from: data)
            } catch {
                throw ForgotPasswordWorkerError.decodingFailed
            }
        }
    }
}
