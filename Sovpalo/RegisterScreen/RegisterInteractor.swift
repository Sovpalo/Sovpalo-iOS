//
//  RegisterInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 31.01.2026.
//

import Foundation

protocol RegisterBusinessLogic {
    /// Запускает процесс регистрации
    /// - Parameters:
    ///   - username: Имя пользователя
    ///   - email: Почта
    ///   - password: Пароль
    func register(username: String, email: String, password: String)

    /// Проверяет пароль на лету во время ввода
    func validatePassword(_ password: String)

    /// Открывает Telegram-авторизацию для регистрации
    func registerWithTelegram()
    func completeTelegramSignIn(initData: String)
    func completeTelegramSignIn(payload: TelegramSignInPayload)
}

final class RegisterInteractor: RegisterBusinessLogic {
    var presenter: RegisterPresenterProtocol?
    var worker: RegisterWorkerProtocol?

    func registerWithTelegram() {
        guard let worker else {
            presenter?.presentRegisterError("Worker is unavailable")
            return
        }

        presenter?.presentLoading(true)
        Task { [weak self] in
            do {
                let url = try await worker.telegramAuthURL()
                await MainActor.run { [weak self] in
                    self?.presenter?.presentLoading(false)
                    self?.presenter?.presentTelegramAuth(url: url)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.presenter?.presentLoading(false)
                    self?.presenter?.presentRegisterError(error.localizedDescription)
                }
            }
        }
    }

    func completeTelegramSignIn(initData: String) {
        let trimmed = initData.trimmingCharacters(in: .whitespacesAndNewlines)
        completeTelegramSignIn(
            payload: TelegramSignInPayload(
                initData: trimmed,
                id: nil,
                firstName: nil,
                lastName: nil,
                username: nil,
                photoURL: nil,
                authDate: nil,
                hash: nil
            )
        )
    }

    func completeTelegramSignIn(payload: TelegramSignInPayload) {
        guard let worker else {
            presenter?.presentRegisterError("Worker is unavailable")
            return
        }
        guard payload.isValid else {
            presenter?.presentRegisterError("Некорректные данные Telegram авторизации")
            return
        }

        presenter?.presentLoading(true)
        Task { [weak self] in
            do {
                _ = try await worker.signInTelegram(payload: payload)
                await MainActor.run { [weak self] in
                    AppMetricaService.refreshUserProfileID()
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.userSignedIn,
                        parameters: [
                            "screen": "RegisterScreen",
                            "auth_method": "telegram"
                        ]
                    )
                    self?.presenter?.presentLoading(false)
                    self?.presenter?.presentTelegramSignInSuccess()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.presenter?.presentLoading(false)
                    self?.presenter?.presentRegisterError(error.localizedDescription)
                }
            }
        }
    }

    func validatePassword(_ password: String) {
        let validation = worker?.validatePassword(password) ?? RegisterPasswordValidation(
            hasUppercaseLetter: false,
            hasLowercaseLetter: false,
            hasThreeDigits: false,
            hasSpecialCharacter: false,
            hasMinimumLength: false,
            isEmpty: password.isEmpty
        )

        presenter?.presentPasswordValidation(validation)
    }
    
    func register(username: String, email: String, password: String) {
        guard let worker else {
            Task { @MainActor [weak self] in
                self?.presenter?.presentRegisterError("Worker is unavailable")
            }
            return
        }

        let validation = worker.validatePassword(password)
        presenter?.presentPasswordValidation(validation)

        guard validation.isValid else {
            presenter?.presentRegisterError(RegisterError.invalidPassword.localizedDescription)
            return
        }

        presenter?.presentLoading(true)

        Task { [weak self] in
            do {
                try await worker.register(email: email, username: username, password: password)
                print("[RegisterInteractor] Registration started for email: \(email)")
                await MainActor.run { [weak self] in
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.userRegistered,
                        parameters: [
                            "screen": "RegisterScreen",
                            "has_username": !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ]
                    )
                    self?.presenter?.presentLoading(false)
                    self?.presenter?.presentRegisterSuccess(email: email)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.presenter?.presentLoading(false)
                    self?.presenter?.presentRegisterError(error.localizedDescription)
                }
            }
        }
    }
}
