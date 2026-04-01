//
//  VerifivationWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol VerifivationWorkerProtocol {
    func verifyRegistration(email: String, code: String) async throws
    func verifyForgotPassword(email: String, code: String, newPassword: String) async throws
}

private struct VerifyRegistrationRequestBody: Encodable {
    let email: String
    let code: String
}

private struct VerifyRegistrationResponseBody: Decodable {
    let token: String
}

private struct VerifyForgotPasswordRequestBody: Encodable {
    let email: String
    let code: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case email
        case code
        case newPassword = "new_password"
    }
}

private struct VerifyForgotPasswordResponseBody: Decodable {
    let message: String?
}

final class VerifivationWorker: VerifivationWorkerProtocol {
    private let baseURL: URL?
    private let session: URLSession
    private let keychain: KeychainLogic

    init(
        baseURL: URL? = URL(string: "http://localhost:8000"),
        session: URLSession = .shared,
        keychain: KeychainLogic = KeychainService()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.keychain = keychain
    }

    func verifyRegistration(email: String, code: String) async throws {
        guard let baseURL else {
            throw VerificationError.invalidURL
        }

        let endpoint = baseURL.appendingPathComponent("/auth/sign-up/verify")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            VerifyRegistrationRequestBody(email: email, code: code)
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VerificationError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw VerificationError.badStatus(code: httpResponse.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(VerifyRegistrationResponseBody.self, from: data)
            keychain.setData(Data(decoded.token.utf8), forKey: "auth.token")
        } catch {
            throw VerificationError.decodingFailed
        }
    }

    func verifyForgotPassword(email: String, code: String, newPassword: String) async throws {
        guard let baseURL else {
            throw VerificationError.invalidURL
        }

        let endpoint = baseURL.appendingPathComponent("/auth/password/verify")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            VerifyForgotPasswordRequestBody(
                email: email,
                code: code,
                newPassword: newPassword
            )
        )

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VerificationError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw VerificationError.badStatus(code: httpResponse.statusCode)
        }

        if !data.isEmpty {
            do {
                _ = try JSONDecoder().decode(VerifyForgotPasswordResponseBody.self, from: data)
            } catch {
                throw VerificationError.decodingFailed
            }
        }
    }
}
