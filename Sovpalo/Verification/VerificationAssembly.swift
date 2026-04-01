//
//  VerificationAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import UIKit

final class VerificationAssembly {
    static func assembly() -> VerificationVC {
        let vc = VerificationVC()
        let interactor = VerificationInteractor()
        let presenter = VerificationPresenter()
        let worker = VerifivationWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
