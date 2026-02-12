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

enum FirstGroupInteractorError: Error {
    case workerUnavailable
    case tokenNotFound
    case tokenDecodingFailed
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

                print("[FirstGroupInteractor] Requesting companies from worker...")
                let companies = try await worker.GetCompaniesList(token: token)
                print("[FirstGroupInteractor] Received companies: \(companies.count)")
                await MainActor.run { [weak self] in
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

