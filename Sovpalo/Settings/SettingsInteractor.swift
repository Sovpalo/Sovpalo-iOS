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
    func deleteAccount()
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
            var didShowCachedProfile = false
            do {
                if let cachedProfile = LocalCacheService.shared.fetchSettingsProfile() {
                    didShowCachedProfile = true
                    let cachedAvatarData = try await loadAvatarDataIfNeeded(profile: cachedProfile, worker: worker)
                    await MainActor.run {
                        self.presenter?.presentProfileLoading(false)
                        self.presenter?.presentProfile(cachedProfile, avatarData: cachedAvatarData)
                    }
                }

                let profile = try await worker.fetchProfile()
                let avatarData = try await loadAvatarDataIfNeeded(profile: profile, worker: worker)
                LocalCacheService.shared.saveSettingsProfile(profile)
                await MainActor.run {
                    self.presenter?.presentProfileLoading(false)
                    self.presenter?.presentProfile(profile, avatarData: avatarData)
                }
            } catch {
                print("[SettingsInteractor] Failed to load profile: \(error)")
                await MainActor.run {
                    self.presenter?.presentProfileLoading(false)
                    if !didShowCachedProfile {
                        self.presenter?.presentError(error.localizedDescription)
                    }
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
                LocalCacheService.shared.saveSettingsProfile(profile)
                await MainActor.run {
                    self.presenter?.presentAvatarUpdating(false)
                    self.presenter?.presentProfile(profile, avatarData: avatarData)
                    self.postCurrentUserAvatarDidChange(profile: profile, avatarData: avatarData)
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
                LocalCacheService.shared.saveSettingsProfile(profile)
                await MainActor.run {
                    self.presenter?.presentAvatarUpdating(false)
                    self.presenter?.presentProfile(profile, avatarData: nil)
                    self.postCurrentUserAvatarDidChange(profile: profile, avatarData: nil)
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
        Task { @MainActor in
            clearSessionData()
            presenter?.presentLogout()
        }
    }

    func deleteAccount() {
        Task { [weak self] in
            guard let self, let worker else { return }

            await MainActor.run {
                self.presenter?.presentDeleteAccountLoading(true)
            }

            do {
                let userID = try currentUserID()
                let companies = try await worker.fetchCompanies()
                let ownedCompanies = companies.filter { $0.createdBy == userID }

                guard ownedCompanies.isEmpty else {
                    await MainActor.run {
                        self.presenter?.presentDeleteAccountLoading(false)
                        self.presenter?.presentError(Self.ownedCompaniesDeletionMessage(ownedCompanies))
                    }
                    return
                }

                try await worker.deleteAccount()
                AppMetricaService.reportEvent(
                    AppMetricaEvent.userLoggedOut,
                    parameters: [
                        "screen": "Settings",
                        "delete_account": true
                    ]
                )

                await MainActor.run {
                    self.presenter?.presentDeleteAccountLoading(false)
                    self.clearSessionData()
                    self.presenter?.presentLogout()
                }
            } catch {
                await MainActor.run {
                    self.presenter?.presentDeleteAccountLoading(false)
                    self.presenter?.presentError(error.localizedDescription)
                }
            }
        }
    }

    @MainActor
    private func clearSessionData() {
        LocalCacheService.shared.clearUserCache()
        URLCache.shared.removeAllCachedResponses()
        keychain.removeData(forKey: "auth.token")
        keychain.removeData(forKey: "auth.userId")
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

    private func postCurrentUserAvatarDidChange(profile: SettingsProfile, avatarData: Data?) {
        var userInfo: [String: Any] = [:]
        if let avatarURL = profile.avatarURL {
            userInfo["avatarURL"] = avatarURL
        }
        if let avatarData {
            userInfo["avatarData"] = avatarData
        }
        NotificationCenter.default.post(name: .currentUserAvatarDidChange, object: nil, userInfo: userInfo)
    }

    private func currentUserID() throws -> Int {
        guard
            let data = keychain.getData(forKey: "auth.userId"),
            let string = String(data: data, encoding: .utf8),
            let userID = Int(string)
        else {
            throw SettingsAccountDeletionError.missingUserID
        }

        return userID
    }

    private static func ownedCompaniesDeletionMessage(_ companies: [Company]) -> String {
        let names = companies
            .map(\.name)
            .prefix(3)
            .joined(separator: ", ")

        if companies.count > 3 {
            return "Перед удалением аккаунта передайте владение группами: \(names) и ещё \(companies.count - 3)."
        }

        return "Перед удалением аккаунта передайте владение группами: \(names)."
    }
}

private enum SettingsAccountDeletionError: LocalizedError {
    case missingUserID

    var errorDescription: String? {
        switch self {
        case .missingUserID:
            return "Не удалось определить текущего пользователя. Попробуйте войти заново."
        }
    }
}

extension Notification.Name {
    static let currentUserAvatarDidChange = Notification.Name("currentUserAvatarDidChange")
}
