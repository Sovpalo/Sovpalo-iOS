//
//  Untitled.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 31.01.2026.
//

import UIKit

final class RegisterAssembly {
    static func assembly() -> RegisterViewController {
        let vc = RegisterViewController()
        let interactor = RegisterInteractor()
        let presenter = RegisterPresenter()
        let worker = RegisterWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
