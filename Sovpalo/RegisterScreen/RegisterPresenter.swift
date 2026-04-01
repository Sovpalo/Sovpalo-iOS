//
//  RegisterPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 31.01.2026.
//

import Foundation
import UIKit

protocol RegisterPresenterProtocol: AnyObject {
    func presentLoading(_ isLoading: Bool)
    func presentRegisterSuccess(email: String)
    func presentRegisterError(_ message: String)
}

final class RegisterPresenter: RegisterPresenterProtocol {
    weak var vc: RegisterViewController?

    func presentLoading(_ isLoading: Bool) {
        vc?.setRegisterLoading(isLoading)
    }
    
    func presentRegisterSuccess(email: String) {
        let verificationVC = VerificationAssembly.assembly(
            email: email,
            flow: .registration
        )
        vc?.navigationController?.pushViewController(verificationVC, animated: true)
    }

    func presentRegisterError(_ message: String) {
        let alert = UIAlertController(title: "Ошибка регистрации", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        vc?.present(alert, animated: true)
    }
}
