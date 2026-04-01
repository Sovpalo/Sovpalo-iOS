//
//  ResendPassAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 02.04.2026.
//

import UIKit

final class ResendPassAssembly {
    static func assembly() -> ResendPassVC {
        var vc = ResendPassVC()
        var interactor = ResendPassInteractor()
        var presenter = ResendPassPresenter()
        var worker = ResendPassWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
