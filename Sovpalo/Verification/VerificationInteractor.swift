//
//  VerificationInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol VerificationBusinessLogic {
    func loadInitialState()
    func verify(code: String, newPassword: String?)
}

enum VerificationFlow {
    case registration
    case forgotPassword
}

enum VerificationError: LocalizedError {
    case invalidCode
    case invalidURL
    case invalidResponse
    case badStatus(code: Int)
    case decodingFailed
    case emptyNewPassword

    var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Неверный код подтверждения"
        case .invalidURL:
            return "Некорректный URL"
        case .invalidResponse:
            return "Некорректный ответ сервера"
        case .badStatus(let code):
            return "Ошибка сервера. Код: \(code)"
        case .decodingFailed:
            return "Не удалось прочитать ответ сервера"
        case .emptyNewPassword:
            return "Введите новый пароль"
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

    func verify(code: String, newPassword: String?) {
        guard code.count == 4 else {
            presenter?.presentVerificationError("Введите 4-х значный код подтверждения")
            return
        }

        guard let worker else {
            presenter?.presentVerificationError("Worker is unavailable")
            return
        }

        presenter?.presentLoading(true)

        Task { [weak self] in
            do {
                guard let self else { return }
                switch self.flow {
                case .registration:
                    try await worker.verifyRegistration(email: self.email, code: code)
                case .forgotPassword:
                    let trimmedPassword = newPassword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard !trimmedPassword.isEmpty else {
                        throw VerificationError.emptyNewPassword
                    }
                    try await worker.verifyForgotPassword(
                        email: self.email,
                        code: code,
                        newPassword: trimmedPassword
                    )
                }
                await MainActor.run {
                    self.presenter?.presentLoading(false)
                    self.presenter?.presentVerificationSuccess(flow: self.flow)
                }
            } catch {
                await MainActor.run {
                    self?.presenter?.presentLoading(false)
                    self?.presenter?.presentVerificationError(error.localizedDescription)
                }
            }
        }
    }
}
