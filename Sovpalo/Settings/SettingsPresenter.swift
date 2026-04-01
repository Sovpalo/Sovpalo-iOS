//
//  SettingsPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation
import UIKit

protocol SettingsPresenterProtocol {
    func presentProfile(_ profile: SettingsProfile)
    func presentLogout()
}

final class SettingsPresenter: SettingsPresenterProtocol {
    weak var vc: SettingsVC?

    func presentProfile(_ profile: SettingsProfile) {
        vc?.display(username: profile.username)
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
