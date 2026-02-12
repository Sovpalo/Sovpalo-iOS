//
//  CreateGroupAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.02.2026.
//

import UIKit

final class CreateGroupAssembly {
    static func assembly() -> CreateGroupVC {
        let vc = CreateGroupVC()
        let interactor = CreateGroupInteractor()
        let presenter = CreateGroupPresenter()
        let worker = CreateGroupWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
