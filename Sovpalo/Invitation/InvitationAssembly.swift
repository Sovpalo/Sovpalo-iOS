//
//  InvitationAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import UIKit

final class InvitationAssembly {
    static func assembly() -> InvitationVC {
        let vc = InvitationVC()
        let interactor = InvitationInteractor()
        let presenter = InvitationPresenter()
        let worker = InvitationWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
