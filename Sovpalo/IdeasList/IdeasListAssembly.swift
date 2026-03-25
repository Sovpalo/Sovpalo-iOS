//
//  IdeasListAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import UIKit

final class IdeasListAssembly {
    static func assembly() -> IdeasListVC {
        var vc = IdeasListVC()
        var interactor = IdeasListInteractor()
        var presenter = IdeasListPresenter()
        var worker = IdeasListWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
