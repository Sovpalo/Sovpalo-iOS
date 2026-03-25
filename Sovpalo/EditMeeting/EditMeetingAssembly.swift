//
//  EditMeetingAssembly.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 25.03.2026.
//

import UIKit

final class EditMeetingAssembly {
    static func assembly(initialData: EditMeetingInitialData) -> EditMeetingVC {
        let vc = EditMeetingVC()
        let interactor = EditMeetingInteractor(initialData: initialData)
        let presenter = EditMeetingPresenter()
        let worker = EditMeetingWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
