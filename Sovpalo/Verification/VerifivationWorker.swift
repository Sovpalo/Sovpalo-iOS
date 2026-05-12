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
    private let network: any NetworkServicing
    private let keychain: KeychainLogic

    init(
        baseURL: URL? = URL(string: Server.url),
        session: URLSession = .shared,
        keychain: KeychainLogic = KeychainService(),
        network: (any NetworkServicing)? = nil
    ) {
        self.keychain = keychain
        self.network = network ?? NetworkService(
            baseURL: baseURL ?? URL(string: Server.url)!,
            session: session,
            keychain: keychain
        )
    }

    func verifyRegistration(email: String, code: String) async throws {
        do {
            let decoded: VerifyRegistrationResponseBody = try await network.decoded(
                path: "auth/sign-up/verify",
                method: .post,
                authorized: false,
                body: VerifyRegistrationRequestBody(email: email, code: code),
                encoder: JSONEncoder(),
                decoder: JSONDecoder(),
                headers: [:]
            )
            keychain.setData(Data(decoded.token.utf8), forKey: "auth.token")
        } catch is DecodingError {
            throw VerificationError.decodingFailed
        }
    }

    func verifyForgotPassword(email: String, code: String, newPassword: String) async throws {
        let data = try await network.data(
            path: "auth/password/verify",
            method: .post,
            authorized: false,
            body: try JSONEncoder().encode(
                VerifyForgotPasswordRequestBody(
                    email: email,
                    code: code,
                    newPassword: newPassword
                )
            ),
            contentType: "application/json",
            headers: [:]
        )

        if !data.isEmpty {
            do {
                _ = try JSONDecoder().decode(VerifyForgotPasswordResponseBody.self, from: data)
            } catch {
                throw VerificationError.decodingFailed
            }
        }
    }
}
