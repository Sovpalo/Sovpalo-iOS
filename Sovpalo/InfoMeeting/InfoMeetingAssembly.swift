//
//  Untitled.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 24.03.2026.
//

import UIKit

final class InfoMeetingAssembly {
    static func assembly(companyId: Int, meetingId: Int, initialMeeting: Meeting?) -> InfoMeetingVC {
        let vc = InfoMeetingVC()
        let interactor = InfoMeetingInteractor(
            companyId: companyId,
            meetingId: meetingId,
            initialMeeting: initialMeeting
        )
        let presenter = InfoMeetingPresenter()
        let worker = InfoMeetingWorker()
        
        vc.interactor = interactor
        interactor.presenter = presenter
        interactor.worker = worker
        presenter.vc = vc
        
        return vc
    }
}
