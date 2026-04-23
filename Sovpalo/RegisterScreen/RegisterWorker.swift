//
//  RegisterWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 31.01.2026.
//

import Foundation

protocol RegisterWorkerProtocol {
    /// Запускает регистрацию и отправку кода подтверждения (POST /auth/sign-up)
    /// - Parameters:
    ///   - email: Электронная почта
    ///   - username: Имя пользователя
    ///   - password: Пароль
    func register(email: String, username: String, password: String) async throws

    /// Проверяет, соответствует ли пароль требованиям
    func validatePassword(_ password: String) -> RegisterPasswordValidation
}

// MARK: - Models

private struct RegisterRequestBody: Codable {
    let email: String
    let username: String
    let password: String
}

private struct RegisterResponseBody: Decodable {
    let message: String?
    let expiresInSec: Int?
}

// MARK: - Errors

enum RegisterError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case http(statusCode: Int)
    case decodingFailed
    case invalidPassword

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .http(let code): return "HTTP error: \(code)"
        case .decodingFailed: return "Failed to decode server response"
        case .invalidPassword: return "Пароль не соответствует требованиям"
        }
    }
}

struct RegisterPasswordValidation {
    let hasUppercaseLetter: Bool
    let hasLowercaseLetter: Bool
    let hasThreeDigits: Bool
    let hasSpecialCharacter: Bool
    let hasMinimumLength: Bool
    let isEmpty: Bool

    var isValid: Bool {
        hasUppercaseLetter &&
        hasLowercaseLetter &&
        hasThreeDigits &&
        hasSpecialCharacter &&
        hasMinimumLength
    }
}

final class RegisterWorker: RegisterWorkerProtocol {
    // MARK: - Dependencies
    private let baseURL: URL?
    private let urlSession: URLSession

    init(
        baseURL: URL? = URL(string: Server.url),
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    // MARK: - API

    func register(email: String, username: String, password: String) async throws {
        guard let baseURL = baseURL else { throw RegisterError.invalidURL }
        let endpoint = baseURL.appendingPathComponent("/auth/sign-up")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = RegisterRequestBody(email: email, username: username, password: password)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw RegisterError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw RegisterError.http(statusCode: http.statusCode) }

        if !data.isEmpty {
            do {
                _ = try JSONDecoder().decode(RegisterResponseBody.self, from: data)
            } catch {
                throw RegisterError.decodingFailed
            }
        }
    }

    func validatePassword(_ password: String) -> RegisterPasswordValidation {
        let digitsCount = password.filter { $0 >= "1" && $0 <= "9" }.count
        let specialCharacters = CharacterSet.punctuationCharacters.union(.symbols)

        return RegisterPasswordValidation(
            hasUppercaseLetter: password.rangeOfCharacter(from: .uppercaseLetters) != nil,
            hasLowercaseLetter: password.rangeOfCharacter(from: .lowercaseLetters) != nil,
            hasThreeDigits: digitsCount >= 3,
            hasSpecialCharacter: password.rangeOfCharacter(from: specialCharacters) != nil,
            hasMinimumLength: password.count >= 8,
            isEmpty: password.isEmpty
        )
    }
}
