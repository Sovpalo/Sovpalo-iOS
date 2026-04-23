//
//  SettingsPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation
import UIKit

protocol SettingsPresenterProtocol {
    func presentProfileLoading(_ isLoading: Bool)
    func presentProfile(_ profile: SettingsProfile, avatarData: Data?)
    func presentAvatarUpdating(_ isUpdating: Bool)
    func presentError(_ message: String)
    func presentLogout()
}

final class SettingsPresenter: SettingsPresenterProtocol {
    weak var vc: SettingsVC?

    func presentProfileLoading(_ isLoading: Bool) {
        vc?.setProfileLoading(isLoading)
    }

    func presentProfile(_ profile: SettingsProfile, avatarData: Data?) {
        vc?.display(username: profile.username, avatarData: avatarData)
    }

    func presentAvatarUpdating(_ isUpdating: Bool) {
        vc?.setAvatarUpdating(isUpdating)
    }

    func presentError(_ message: String) {
        vc?.showErrorAlert(message: message)
    }

    func presentLogout() {
        let startVC = StartAssembly.assembly()
        let navigationController = UINavigationController(rootViewController: startVC)

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            vc?.navigationController?.setViewControllers([startVC], animated: true)
            return
        }

        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
            window.rootViewController = navigationController
        }
    }
}
