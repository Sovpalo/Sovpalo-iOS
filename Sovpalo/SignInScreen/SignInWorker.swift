//
//  SignInWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 28.01.2026.
//

import Foundation

protocol SignInWorkerProtocol {
    /// Performs sign-in and returns an auth token string when successful
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password
    /// - Returns: Token string
    func signIn(email: String, password: String) async throws -> String
}

struct SignInRequestBody: Codable {
    let email: String
    let password: String
}

struct SignInResponseBody: Codable {
    let token: String
}

enum SignInError: Error, LocalizedError {
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

final class SignInWorker: SignInWorkerProtocol {
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

    func signIn(email: String, password: String) async throws -> String {
        let endpoint = baseURL.appendingPathComponent("/auth/sign-in")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = SignInRequestBody(email: email, password: password)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw SignInError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw SignInError.http(statusCode: http.statusCode) }

        let decoded: SignInResponseBody
        do {
            decoded = try JSONDecoder().decode(SignInResponseBody.self, from: data)
        } catch {
            throw SignInError.decodingFailed
        }

        let tokenData = Data(decoded.token.utf8)
        keychain.setData(tokenData, forKey: "auth.token")
        return decoded.token
    }
}

