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

    func signIn(email: String, password: String) {
        guard let worker else { return }
        presenter?.presentLoading(true)
        Task {
            do {
                let token = try await worker.signIn(email: email, password: password)
                print("[SignInInteractor] Received token: \(token)")
                presenter?.presentLoading(false)
                presenter?.presentSignInSuccess()
            } catch {
                print("[SignInInteractor] Sign-in failed with error: \(error)")
                presenter?.presentLoading(false)
                presenter?.presentSignInError(error.localizedDescription)
            }
        }
    }
}
