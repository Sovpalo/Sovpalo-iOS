//
//  FirstGroupInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.02.2026.
//

import Foundation

protocol FirstGroupBusinessLogic {
    /// Инициирует загрузку списка компаний и передаёт результат презентеру
    func getCompaniesList()
}

enum FirstGroupInteractorError: Error, LocalizedError {
    case workerUnavailable
    case tokenNotFound
    case tokenDecodingFailed

    var errorDescription: String? {
        switch self {
        case .workerUnavailable:
            return "Сервис загрузки сейчас недоступен"
        case .tokenNotFound:
            return "Не найден токен авторизации"
        case .tokenDecodingFailed:
            return "Не удалось прочитать токен авторизации"
        }
    }
}

final class FirstGroupInteractor: FirstGroupBusinessLogic {
    var presenter: FirstGroupPresenterProtocol?
    var worker: FirstGroupWorkerProtocol?

    private let keychain: KeychainLogic

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func getCompaniesList() {
        print("[FirstGroupInteractor] getCompaniesList started")

        guard let worker else {
            Task { @MainActor [weak self] in
                print("[FirstGroupInteractor] Worker is unavailable")
                self?.presenter?.presentCompaniesError("Worker is unavailable")
            }
            return
        }

        Task { [weak self] in
            guard let self = self else { return }
            do {
                print("[FirstGroupInteractor] Trying to read token from Keychain with key 'auth.token'")
                // Достаём токен из Keychain
                guard let tokenData = self.keychain.getData(forKey: "auth.token") else {
                    throw FirstGroupInteractorError.tokenNotFound
                }
                guard let token = String(data: tokenData, encoding: .utf8) else {
                    throw FirstGroupInteractorError.tokenDecodingFailed
                }
                print("[FirstGroupInteractor] Token length: \(token.count)")

                print("[FirstGroupInteractor] Requesting companies and username from worker...")
                async let companiesRequest = worker.GetCompaniesList(token: token)
                async let usernameRequest = worker.getCurrentUsername(token: token)

                let companies = try await companiesRequest
                let username = try await usernameRequest
                print("[FirstGroupInteractor] Received companies: \(companies.count)")
                await MainActor.run { [weak self] in
                    self?.presenter?.presentUsername(username)
                    self?.presenter?.presentCompanies(companies)
                }
            } catch {
                print("[FirstGroupInteractor] Load companies error: \(error)")
                await MainActor.run { [weak self] in
                    self?.presenter?.presentCompaniesError(error.localizedDescription)
                }
            }
        }
    }
}
