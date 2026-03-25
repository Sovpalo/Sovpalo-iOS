//
//  CreateIdeasAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import UIKit

final class CreateIdeasAssembly {
    static func assembly(company: Company) -> CreateIdeasVC {
        let vc = CreateIdeasVC()
        let interactor = CreateIdeasInteractor(company: company)
        let presenter = CreateIdeasPresenter()
        let worker = CreateIdeasWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
