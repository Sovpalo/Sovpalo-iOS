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
    func presentPasswordValidation(_ validation: RegisterPasswordValidation)
    func presentRegisterSuccess(email: String)
    func presentRegisterError(_ message: String)
}

struct RegisterPasswordRequirementViewModel {
    let text: String
    let color: UIColor
}

struct RegisterPasswordValidationViewModel {
    let items: [RegisterPasswordRequirementViewModel]
}

final class RegisterPresenter: RegisterPresenterProtocol {
    weak var vc: RegisterViewController?

    func presentLoading(_ isLoading: Bool) {
        vc?.setRegisterLoading(isLoading)
    }

    func presentPasswordValidation(_ validation: RegisterPasswordValidation) {
        let defaultColor: UIColor = validation.isEmpty ? .black : .systemRed
        let successColor: UIColor = .systemGreen

        let viewModel = RegisterPasswordValidationViewModel(items: [
            RegisterPasswordRequirementViewModel(
                text: "• 1 заглавная буква (A-Z)",
                color: validation.hasUppercaseLetter ? successColor : defaultColor
            ),
            RegisterPasswordRequirementViewModel(
                text: "• 1 прописная буква (a-z)",
                color: validation.hasLowercaseLetter ? successColor : defaultColor
            ),
            RegisterPasswordRequirementViewModel(
                text: "• 3 цифры (1-9)",
                color: validation.hasThreeDigits ? successColor : defaultColor
            ),
            RegisterPasswordRequirementViewModel(
                text: "• 1 спец символ",
                color: validation.hasSpecialCharacter ? successColor : defaultColor
            ),
            RegisterPasswordRequirementViewModel(
                text: "• минимум 8 символов",
                color: validation.hasMinimumLength ? successColor : defaultColor
            )
        ])

        vc?.displayPasswordValidation(viewModel)
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
