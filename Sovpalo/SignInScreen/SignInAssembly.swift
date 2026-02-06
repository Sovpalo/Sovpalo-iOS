//
//  RegistrationAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 28.01.2026.
//

import UIKit

final class SignInAssembly {
    static func assembly() -> UIViewController {
        let vc = SignInViewController()
        let interactor = SignInInteractor()
        let presenter = SignInPresenter()
        let worker = SignInWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
