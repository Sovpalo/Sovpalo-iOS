//
//  RegisterWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 31.01.2026.
//

import Foundation

protocol RegisterWorkerProtocol {
    /// Регистрирует пользователя (POST /auth/sign-up)
    /// - Parameters:
    ///   - email: Электронная почта
    ///   - username: Имя пользователя
    ///   - password: Пароль
    /// - Returns: Токен авторизации
    func register(email: String, username: String, password: String) async throws -> String
}

// MARK: - Models

private struct RegisterRequestBody: Codable {
    let email: String
    let username: String
    let password: String
}

private struct RegisterResponseBody: Decodable {
    let token: String
}

// MARK: - Errors

enum RegisterError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case http(statusCode: Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .http(let code): return "HTTP error: \(code)"
        case .decodingFailed: return "Failed to decode server response"
        }
    }
}

final class RegisterWorker: RegisterWorkerProtocol {
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

    func register(email: String, username: String, password: String) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("/auth/sign-up")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RegisterRequestBody(email: email, username: username, password: password)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw RegisterError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw RegisterError.http(statusCode: http.statusCode) }

        let decoded: RegisterResponseBody
        do {
            decoded = try JSONDecoder().decode(RegisterResponseBody.self, from: data)
        } catch {
            throw RegisterError.decodingFailed
        }

        let tokenData = Data(decoded.token.utf8)
        keychain.setData(tokenData, forKey: "auth.token")
        return decoded.token
    }
}
