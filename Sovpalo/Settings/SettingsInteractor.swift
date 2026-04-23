//
//  SettingsInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol SettingsBusinessLogic {
    func loadProfile()
    func uploadAvatar(imageData: Data, fileName: String, mimeType: String)
    func deleteAvatar()
    func logout()
}

struct SettingsProfile {
    let username: String
    let avatarURL: String?
}

final class SettingsInteractor: SettingsBusinessLogic {
    var presenter: SettingsPresenterProtocol?
    var worker: SettingsWorkerProtocol?
    private let keychain: KeychainLogic

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func loadProfile() {
        presenter?.presentProfileLoading(true)
        Task { [weak self] in
            guard let self, let worker else { return }
            do {
                let profile = try await worker.fetchProfile()
                let avatarData = try await loadAvatarDataIfNeeded(profile: profile, worker: worker)
                await MainActor.run {
                    self.presenter?.presentProfileLoading(false)
                    self.presenter?.presentProfile(profile, avatarData: avatarData)
                }
            } catch {
                print("[SettingsInteractor] Failed to load profile: \(error)")
                await MainActor.run {
                    self.presenter?.presentProfileLoading(false)
                    self.presenter?.presentError(error.localizedDescription)
                }
            }
        }
    }

    func uploadAvatar(imageData: Data, fileName: String, mimeType: String) {
        presenter?.presentAvatarUpdating(true)

        Task { [weak self] in
            guard let self, let worker else { return }
            do {
                let profile = try await worker.uploadAvatar(
                    imageData: imageData,
                    fileName: fileName,
                    mimeType: mimeType
                )
                let avatarData = try await loadAvatarDataIfNeeded(profile: profile, worker: worker)
                await MainActor.run {
                    self.presenter?.presentAvatarUpdating(false)
                    self.presenter?.presentProfile(profile, avatarData: avatarData)
                }
            } catch {
                print("[SettingsInteractor] Failed to upload avatar: \(error)")
                await MainActor.run {
                    self.presenter?.presentAvatarUpdating(false)
                    self.presenter?.presentError(error.localizedDescription)
                }
            }
        }
    }

    func deleteAvatar() {
        presenter?.presentAvatarUpdating(true)

        Task { [weak self] in
            guard let self, let worker else { return }
            do {
                let profile = try await worker.deleteAvatar()
                await MainActor.run {
                    self.presenter?.presentAvatarUpdating(false)
                    self.presenter?.presentProfile(profile, avatarData: nil)
                }
            } catch {
                print("[SettingsInteractor] Failed to delete avatar: \(error)")
                await MainActor.run {
                    self.presenter?.presentAvatarUpdating(false)
                    self.presenter?.presentError(error.localizedDescription)
                }
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

    private func loadAvatarDataIfNeeded(
        profile: SettingsProfile,
        worker: SettingsWorkerProtocol
    ) async throws -> Data? {
        guard let avatarURL = profile.avatarURL, !avatarURL.isEmpty else {
            return nil
        }

        do {
            return try await worker.fetchAvatarData(from: avatarURL)
        } catch {
            print("[SettingsInteractor] Failed to load avatar image: \(error)")
            return nil
        }
    }
}
