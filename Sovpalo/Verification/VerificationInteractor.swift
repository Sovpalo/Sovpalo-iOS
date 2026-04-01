//
//  VerificationInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol VerificationBusinessLogic {
    func loadInitialState()
    func verify(code: String)
}

enum VerificationFlow {
    case registration
    case forgotPassword
}

enum VerificationError: LocalizedError {
    case invalidCode

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Неверный код подтверждения"
        }
    }
}

final class VerificationInteractor: VerificationBusinessLogic {
    var presenter: VerificationPresenterProtocol?
    var worker: VerifivationWorkerProtocol?
    private let email: String
    private let flow: VerificationFlow

    init(email: String, flow: VerificationFlow) {
        self.email = email
        self.flow = flow
    }

    func loadInitialState() {
        presenter?.presentInitialState(email: email, flow: flow)
    }

    func verify(code: String) {
        guard code.count == 4 else {
            presenter?.presentVerificationError("Введите 4-х значный код подтверждения")
            return
        }

        guard let worker else {
            presenter?.presentVerificationError("Worker is unavailable")
            return
        }

        Task { [weak self] in
            do {
                guard let self else { return }
                try await worker.verify(email: self.email, code: code, flow: self.flow)
                await MainActor.run {
                    self.presenter?.presentVerificationSuccess(flow: self.flow)
                }
            } catch {
                await MainActor.run {
                    self?.presenter?.presentVerificationError(error.localizedDescription)
                }
            }
        }
    }
}
