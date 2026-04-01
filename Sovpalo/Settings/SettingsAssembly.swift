//
//  SettingsAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import UIKit

final class SettingsAssembly {
    static func assembly() -> SettingsVC {
        let vc = SettingsVC()
        let interactor = SettingsInteractor()
        let presenter = SettingsPresenter()
        let worker = SettingsWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
