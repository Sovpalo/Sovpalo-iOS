//
//  VerifivationWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol VerifivationWorkerProtocol {
    func verify(email: String, code: String, flow: VerificationFlow) async throws
}

final class VerifivationWorker: VerifivationWorkerProtocol {
    func verify(email: String, code: String, flow: VerificationFlow) async throws {
        try await Task.sleep(nanoseconds: 150_000_000)

        guard code == "0000" else {
            throw VerificationError.invalidCode
        }
    }
}
