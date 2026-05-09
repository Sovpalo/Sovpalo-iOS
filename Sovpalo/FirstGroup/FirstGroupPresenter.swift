//
//  FirstGroupPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.02.2026.
//

import UIKit

protocol FirstGroupPresenterProtocol {
    func presentCompanies(_ companies: [Company])
    func presentUsername(_ username: String)
    func presentCompaniesError(_ message: String)
    func presentSessionExpired()
}

final class FirstGroupPresenter: FirstGroupPresenterProtocol {
    weak var vc: FirstGroupVC?

    func presentCompanies(_ companies: [Company]) {
        DispatchQueue.main.async { [weak vc] in
            vc?.companies = companies
        }
    }

    func presentUsername(_ username: String) {
        DispatchQueue.main.async { [weak vc] in
            vc?.displayUsername(username)
        }
    }

    func presentCompaniesError(_ message: String) {
        DispatchQueue.main.async { [weak vc] in
            guard let viewController = vc else { return }
            let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            viewController.present(alert, animated: true)
        }
    }

    func presentSessionExpired() {
        DispatchQueue.main.async {
            let startVC = StartAssembly.assembly()
            let navigationController = UINavigationController(rootViewController: startVC)

            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                self.vc?.navigationController?.setViewControllers([startVC], animated: true)
                return
            }

            UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
                window.rootViewController = navigationController
            }
        }
    }
}
