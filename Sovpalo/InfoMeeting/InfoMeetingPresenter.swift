//
//  InfoMeetingPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 24.03.2026.
//

import Foundation

struct InfoMeetingViewModel {
    let title: String
    let timeText: String
    let locationText: String
    let goingPeople: [String]
    let notGoingPeople: [String]
    let descriptionText: String
}

protocol InfoMeetingPresenterProtocol: AnyObject {
    func presentMeeting(_ viewModel: InfoMeetingViewModel)
    func presentError(_ message: String)
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
}
