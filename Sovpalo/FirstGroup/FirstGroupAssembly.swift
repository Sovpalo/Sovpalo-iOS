//
//  FirstGroupAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.02.2026.
//

import UIKit

final class FirstGroupAssembly {
    static func assembly() -> FirstGroupVC {
        let vc = FirstGroupVC()
        let interactor = FirstGroupInteractor()
        let presenter = FirstGroupPresenter()
        let worker = FirstGroupWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        return vc
    }
}
