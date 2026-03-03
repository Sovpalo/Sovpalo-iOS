//
//  RegisterPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 31.01.2026.
//

import Foundation
import UIKit

protocol RegisterPresenterProtocol: AnyObject {
    func presentRegisterSuccess()
    func presentRegisterError(_ message: String)
}

final class RegisterPresenter: RegisterPresenterProtocol {
    weak var vc: RegisterViewController?
    
    func presentRegisterSuccess() {
        // После успешной регистрации ведём пользователя к экрану выбора/создания компании
        let firstGroupVC = FirstGroupAssembly.assembly()
        vc?.navigationController?.setViewControllers([firstGroupVC], animated: true)
    }

    func presentRegisterError(_ message: String) {
        let alert = UIAlertController(title: "Ошибка регистрации", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        vc?.present(alert, animated: true)
    }
}
