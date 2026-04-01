//
//  SettingsWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol SettingsWorkerProtocol {
    func fetchProfile() async throws -> SettingsProfile
}

final class SettingsWorker: SettingsWorkerProtocol {
    func fetchProfile() async throws -> SettingsProfile {
        try await Task.sleep(nanoseconds: 150_000_000)
        return SettingsProfile(username: "username")
    }
}
