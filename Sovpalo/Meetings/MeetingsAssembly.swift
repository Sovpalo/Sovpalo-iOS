//
//  MeetingsAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import UIKit

final class MeetingsAssembly {
    static func assembly() -> MeetingsVC {
        let vc = MeetingsVC()
        let interactor = MeetingsInteractor()
        let presenter = MeetingsPresenter()
        let worker = MeetingsWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
