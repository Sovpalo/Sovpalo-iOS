//
//  SignInWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 28.01.2026.
//
import Foundation

protocol SignInWorkerProtocol {
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
        case .invalidURL:              return "Invalid URL"
        case .invalidResponse:         return "Invalid server response"
        case .http(let code):          return "HTTP error: \(code)"
        case .decodingFailed:          return "Failed to decode server response"
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

        // Save token
        keychain.setData(Data(decoded.token.utf8), forKey: "auth.token")

        // ← NEW: decode user ID from JWT and save it too
        if let userID = decodeUserIDFromJWT(decoded.token) {
            keychain.setData(Data("\(userID)".utf8), forKey: "auth.userId")
        }

        return decoded.token
    }

    // ← NEW: extracts user_id from JWT payload
    private func decodeUserIDFromJWT(_ token: String) -> Int? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }

        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userID = json["user_id"] as? Int else { return nil }

        return userID
    }
}
