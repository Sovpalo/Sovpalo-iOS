//
//  CreateIdeasAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import UIKit

final class CreateIdeasAssembly {
    static func assembly(company: Company, prefill: CreateIdeaRequest? = nil) -> CreateIdeasVC {
        let vc = CreateIdeasVC()
        vc.prefill = prefill
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
