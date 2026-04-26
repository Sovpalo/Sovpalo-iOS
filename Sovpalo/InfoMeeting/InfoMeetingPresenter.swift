//
//  InfoMeetingPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 24.03.2026.
//

import UIKit

struct InfoMeetingViewModel {
    let title: String
    let timeText: String
    let locationText: String
    let photoURL: String?
    let goingPeople: [String]
    let notGoingPeople: [String]
    let descriptionText: String
}

protocol InfoMeetingPresenterProtocol: AnyObject {
    func presentMeeting(_ viewModel: InfoMeetingViewModel)
    func presentError(_ message: String)
    func routeToEditMeeting(initialData: EditMeetingInitialData)
    func routeBackAfterDelete()
}

final class InfoMeetingPresenter: InfoMeetingPresenterProtocol {
    weak var vc: InfoMeetingVC?

    func presentMeeting(_ viewModel: InfoMeetingViewModel) {
        DispatchQueue.main.async { [weak vc] in
            vc?.apply(viewModel: viewModel)
        }
    }

    func presentError(_ message: String) {
        DispatchQueue.main.async { [weak vc] in
            vc?.showError(message: message)
        }
    }

    func routeToEditMeeting(initialData: EditMeetingInitialData) {
        DispatchQueue.main.async { [weak vc] in
            let editVC = EditMeetingAssembly.assembly(initialData: initialData)
            vc?.navigationController?.pushViewController(editVC, animated: true)
        }
    }
    
    func routeBackAfterDelete() {
        DispatchQueue.main.async { [weak vc] in
            vc?.navigationController?.popViewController(animated: true)
        }
    }
}
