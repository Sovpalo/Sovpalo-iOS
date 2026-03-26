//
//  InviteUserAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.03.2026.
//

final class InviteUserAssembly {
    static func assembly(companyId: Int, shouldPopOnDone: Bool = false) -> InviteUserVC {
        let vc = InviteUserVC()
        let interactor = InviteUserInteractor(companyId: companyId)
        let presenter = InviteUserPresenter()
        let worker = InviteUserWorker()

        vc.interactor = interactor
        vc.shouldPopOnDone = shouldPopOnDone

        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc

        return vc
    }
}
