//
//  VerificationAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import UIKit

final class VerificationAssembly {
    static func assembly(email: String, flow: VerificationFlow) -> VerificationVC {
        let vc = VerificationVC()
        let interactor = VerificationInteractor(email: email, flow: flow)
        let presenter = VerificationPresenter()
        let worker = VerifivationWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
