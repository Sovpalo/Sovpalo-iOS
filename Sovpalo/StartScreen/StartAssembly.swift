//
//  StartAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 24.01.2026.
//

import UIKit

final class StartAssembly {
    static func assembly() -> UIViewController {
        let vc = StartViewController()
        let interactor = StartInteractor()
        let presenter = StartPresenter()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        presenter.vc = vc
        
        return vc
    }
}
