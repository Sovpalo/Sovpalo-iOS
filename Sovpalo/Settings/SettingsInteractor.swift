//
//  SettingsInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol SettingsBusinessLogic {
    func loadProfile()
    func logout()
}

struct SettingsProfile {
    let username: String
}

final class SettingsInteractor: SettingsBusinessLogic {
    var presenter: SettingsPresenterProtocol?
    var worker: SettingsWorkerProtocol?
    private let keychain: KeychainLogic

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func loadProfile() {
        Task {
            do {
                guard let worker else { return }
                let profile = try await worker.fetchProfile()
                await MainActor.run {
                    self.presenter?.presentProfile(profile)
                }
            } catch {
                print("[SettingsInteractor] Failed to load profile: \(error)")
            }
        }
    }

    func logout() {
        AppMetricaService.reportEvent(
            AppMetricaEvent.userLoggedOut,
            parameters: [
                "screen": "Settings"
            ]
        )
        keychain.removeData(forKey: "auth.token")
        keychain.removeData(forKey: "auth.userId")
        presenter?.presentLogout()
    }
}
