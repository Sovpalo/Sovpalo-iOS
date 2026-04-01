//
//  ForgotPasswordInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol ForgotPasswordBusinessLogic {
    func continueWithEmail(_ email: String)
}

final class ForgotPasswordInteractor: ForgotPasswordBusinessLogic {
    var presenter: ForgotPasswordPresenterProtocol?
    var worker: ForgorPasswordWorkerProtocol?

    func continueWithEmail(_ email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            presenter?.presentError("Введите email")
            return
        }

        guard let worker else {
            presenter?.presentError("Worker is unavailable")
            return
        }

        Task { [weak self] in
            do {
                try await worker.requestPasswordReset(email: trimmedEmail)
                await MainActor.run {
                    self?.presenter?.presentVerification(email: trimmedEmail)
                }
            } catch {
                await MainActor.run {
                    self?.presenter?.presentError(error.localizedDescription)
                }
            }
        }
    }
}
