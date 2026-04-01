//
//  ForgotPasswordAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import UIKit

final class ForgotPasswordAssembly {
    static func assembly() -> ForgotPasswordVC {
        let vc = ForgotPasswordVC()
        let interactor = ForgotPasswordInteractor()
        let presenter = ForgotPasswordPresenter()
        let worker = ForgorPasswordWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
