//
//  InviteUserAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.03.2026.
//

import UIKit

final class InviteUserAssembly {
    static func assembly(companyId: Int) -> InviteUserVC {
        let vc = InviteUserVC()
        let interactor = InviteUserInteractor(companyId: companyId)
        let presenter = InviteUserPresenter()
        let worker = InviteUserWorker()

        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc

        return vc
    }
}
