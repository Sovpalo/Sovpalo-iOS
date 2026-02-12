//
//  RegistrationPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 28.01.2026.
//

import UIKit

protocol SignInPresenterProtocol {
    func presentSignInSuccess()
    func presentSignInError(_ message: String)
}

final class SignInPresenter: SignInPresenterProtocol {
    weak var vc: SignInViewController?
    
    func presentSignInSuccess() {
        let mainVC = FirstGroupAssembly.assembly()
        vc?.navigationController?.setViewControllers([mainVC], animated: true)
    }
    
    func presentSignInError(_ message: String) {
        vc?.showSignInErrorAlert(message: message)
    }
    
}
