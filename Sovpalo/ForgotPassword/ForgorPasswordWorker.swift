//
//  ForgorPasswordWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol ForgorPasswordWorkerProtocol {
    func requestPasswordReset(email: String) async throws
}

final class ForgorPasswordWorker: ForgorPasswordWorkerProtocol {
    func requestPasswordReset(email: String) async throws {
        try await Task.sleep(nanoseconds: 150_000_000)
    }
}
