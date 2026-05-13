//
//  SignInWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 28.01.2026.
//
import Foundation

protocol SignInWorkerProtocol {
    func signIn(email: String, password: String) async throws -> String
    func signInWithApple(identityToken: String, nonce: String, email: String?, givenName: String?, familyName: String?) async throws -> String
}

struct SignInRequestBody: Codable {
    let email: String
    let password: String
}

struct SignInResponseBody: Codable {
    let token: String
}

private struct AppleSignInRequestBody: Encodable {
    let identityToken: String
    let nonce: String
    let email: String?
    let givenName: String?
    let familyName: String?

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case nonce
        case email
        case givenName = "given_name"
        case familyName = "family_name"
    }
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
    private let baseURL: URL?
    private let urlSession: URLSession
    private let keychain: KeychainLogic

    init(
        baseURL: URL? = URL(string: Server.url),
        urlSession: URLSession = .shared,
        keychain: KeychainLogic = KeychainService()
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.keychain = keychain
    }

    func signIn(email: String, password: String) async throws -> String {
        guard let baseURL = baseURL else { throw SignInError.invalidURL }
        let endpoint = baseURL.appendingPathComponent("/auth/sign-in")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = SignInRequestBody(email: email, password: password)
        request.httpBody = try JSONEncoder().encode(body)

        print("[SignInWorker] POST \(endpoint.absoluteString)")
        print("[SignInWorker] Request body: email=\(email), passwordLength=\(password.count)")

        let (data, response) = try await urlSession.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw SignInError.invalidResponse }
        let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8 body, \(data.count) bytes>"

        print("[SignInWorker] Response status: \(http.statusCode)")
        print("[SignInWorker] Response body: \(rawBody)")

        guard (200..<300).contains(http.statusCode) else {
            print("[SignInWorker] HTTP error \(http.statusCode)")
            throw SignInError.http(statusCode: http.statusCode)
        }

        let decoded: SignInResponseBody
        do {
            decoded = try JSONDecoder().decode(SignInResponseBody.self, from: data)
        } catch {
            print("[SignInWorker] Decoding error: \(error)")
            throw SignInError.decodingFailed
        }

        saveAuthToken(decoded.token)

        return decoded.token
    }

    func signInWithApple(identityToken: String, nonce: String, email: String?, givenName: String?, familyName: String?) async throws -> String {
        guard let baseURL = baseURL else { throw SignInError.invalidURL }
        let endpoint = baseURL.appendingPathComponent("/auth/apple/sign-in")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            AppleSignInRequestBody(
                identityToken: identityToken,
                nonce: nonce,
                email: email,
                givenName: givenName,
                familyName: familyName
            )
        )

        print("[SignInWorker] POST \(endpoint.absoluteString)")
        print("[SignInWorker] Apple request body: identityTokenLength=\(identityToken.count), nonceLength=\(nonce.count)")

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SignInError.invalidResponse }
        let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8 body, \(data.count) bytes>"

        print("[SignInWorker] Apple response status: \(http.statusCode)")
        print("[SignInWorker] Apple response body: \(rawBody)")

        guard (200..<300).contains(http.statusCode) else {
            throw SignInError.http(statusCode: http.statusCode)
        }

        let decoded: SignInResponseBody
        do {
            decoded = try JSONDecoder().decode(SignInResponseBody.self, from: data)
        } catch {
            print("[SignInWorker] Apple decoding error: \(error)")
            throw SignInError.decodingFailed
        }

        saveAuthToken(decoded.token)
        return decoded.token
    }

    private func saveAuthToken(_ token: String) {
        keychain.setData(Data(token.utf8), forKey: "auth.token")

        if let userID = decodeUserIDFromJWT(token) {
            keychain.setData(Data("\(userID)".utf8), forKey: "auth.userId")
        }
    }

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
