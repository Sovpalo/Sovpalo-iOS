//
//  CreateGroupWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.02.2026.
//

import Foundation

// MARK: - Models

private struct CreateCompanyRequest: Codable {
    let name: String
    let description: String?
}

private struct CreateCompanyResponse: Decodable {
    let id: Int
}

// MARK: - Errors

enum CreateGroupWorkerError: Error, LocalizedError {
    case invalidURL
    case tokenNotFound
    case tokenDecodingFailed
    case badStatus(code: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .tokenNotFound: return "Auth token not found"
        case .tokenDecodingFailed: return "Failed to decode auth token"
        case .badStatus(let code): return "HTTP error: \(code)"
        }
    }
}

protocol CreateGroupWorkerProtocol {
    /// Создаёт компанию (POST /companies)
    /// - Parameters:
    ///   - name: Название компании
    ///   - description: Описание компании (опционально)
    /// - Returns: Идентификатор созданной компании
    func createCompany(name: String, description: String?) async throws -> Int
}

final class CreateGroupWorker: CreateGroupWorkerProtocol {

    // MARK: - Dependencies
    private let baseURL: URL
    private let urlSession: URLSession
    private let keychain: KeychainLogic

    init(
        baseURL: URL = URL(string: "http://localhost:8000")!,
        urlSession: URLSession = .shared,
        keychain: KeychainLogic = KeychainService()
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.keychain = keychain
    }

    // MARK: - API

    func createCompany(name: String, description: String?) async throws -> Int {
        // 1) Получаем токен из Keychain
        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw CreateGroupWorkerError.tokenNotFound
        }
        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw CreateGroupWorkerError.tokenDecodingFailed
        }

        // 2) Готовим запрос
        let endpoint = baseURL.appendingPathComponent("/companies")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = CreateCompanyRequest(name: name, description: description)
        request.httpBody = try JSONEncoder().encode(body)

        // 3) Выполняем запрос
        let (data, response) = try await urlSession.data(for: request)

        // 4) Валидация ответа
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CreateGroupWorkerError.badStatus(code: code)
        }

        // 5) Декодим ответ: ожидаем хотя бы id
        let decoded = try JSONDecoder().decode(CreateCompanyResponse.self, from: data)
        return decoded.id
    }
}
