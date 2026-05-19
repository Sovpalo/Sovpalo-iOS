//
//  SignInInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 28.01.2026.
//

import Foundation

protocol SignInBusinessLogic {
    /// Starts sign-in flow with provided credentials
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password
    func signIn(email: String, password: String)
}

final class SignInInteractor: SignInBusinessLogic {
    var presenter: SignInPresenterProtocol?
    var worker: SignInWorkerProtocol?
    private var isSigningIn = false

    func signIn(email: String, password: String) {
        guard !isSigningIn else { return }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            presenter?.presentSignInError("Введите email и пароль")
            return
        }

        guard let worker else { return }

        isSigningIn = true
        presenter?.presentLoading(true)
        Task { [weak self] in
            do {
                let token = try await worker.signIn(email: trimmedEmail, password: trimmedPassword)
                print("[SignInInteractor] Received token: \(token)")
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.isSigningIn = false
                    AppMetricaService.refreshUserProfileID()
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.userSignedIn,
                        parameters: [
                            "screen": "SignInScreen",
                            "auth_method": "password"
                        ]
                    )
                    self.presenter?.presentLoading(false)
                    self.presenter?.presentSignInSuccess()
                }
            } catch {
                print("[SignInInteractor] Sign-in failed with error: \(error)")
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.isSigningIn = false
                    self.presenter?.presentLoading(false)
                    self.presenter?.presentSignInError(error.localizedDescription)
                }
            }
        }
    }

}
