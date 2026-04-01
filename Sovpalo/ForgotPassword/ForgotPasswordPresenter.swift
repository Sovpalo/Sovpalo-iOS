//
//  ForgotPasswordPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation
import UIKit

protocol ForgotPasswordPresenterProtocol {
    func presentVerification(email: String)
    func presentError(_ message: String)
}

final class ForgotPasswordPresenter: ForgotPasswordPresenterProtocol {
    weak var vc: ForgotPasswordVC?

    func presentVerification(email: String) {
        let verificationVC = VerificationAssembly.assembly(
            email: email,
            flow: .forgotPassword
        )
        vc?.navigationController?.pushViewController(verificationVC, animated: true)
    }

    func presentError(_ message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        vc?.present(alert, animated: true)
    }
}
