//
//  IdeasListAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import UIKit

final class IdeasListAssembly {
    static func assembly(company: Company) -> IdeasListVC {
        let vc = IdeasListVC()
        let interactor = IdeasListInteractor(company: company)
        let presenter = IdeasListPresenter()
        let worker = IdeasListWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
