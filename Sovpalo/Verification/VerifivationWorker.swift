//
//  VerifivationWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol VerifivationWorkerProtocol {
    func verifyRegistration(email: String, code: String) async throws
    func verifyForgotPassword(email: String, code: String) async throws
}

final class VerifivationWorker: VerifivationWorkerProtocol {
    func verifyRegistration(email: String, code: String) async throws {
        try await performMockVerification(email: email, code: code)
    }

    func verifyForgotPassword(email: String, code: String) async throws {
        try await performMockVerification(email: email, code: code)
    }

    private func performMockVerification(email: String, code: String) async throws {
        try await Task.sleep(nanoseconds: 150_000_000)

        guard code == "0000" else {
            throw VerificationError.invalidCode
        }
    }
}
