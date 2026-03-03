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
}

final class RegisterInteractor: RegisterBusinessLogic {
    var presenter: RegisterPresenterProtocol?
    var worker: RegisterWorkerProtocol?
    
    func register(username: String, email: String, password: String) {
        guard let worker else {
            Task { @MainActor [weak self] in
                self?.presenter?.presentRegisterError("Worker is unavailable")
            }
            return
        }

        Task { [weak self] in
            do {
                let token = try await worker.register(email: email, username: username, password: password)
                print("[RegisterInteractor] Received token: \(token)")
                await MainActor.run { [weak self] in
                    self?.presenter?.presentRegisterSuccess()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.presenter?.presentRegisterError(error.localizedDescription)
                }
            }
        }
    }
}
