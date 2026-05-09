//
//  AIGenerateIdeaAssembly.swift
//  Sovpalo
//

import UIKit

enum AIGenerateIdeaAssembly {
    static func assembly(company: Company) -> AIGenerateIdeaVC {
        let vc = AIGenerateIdeaVC()
        let interactor = AIGenerateIdeaInteractor(company: company)
        let presenter = AIGenerateIdeaPresenter(company: company)
        let worker = AIGenerateIdeaWorker()

        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc

        return vc
    }
}
