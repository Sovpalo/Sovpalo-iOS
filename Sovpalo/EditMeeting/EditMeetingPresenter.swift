//
//  EditMeetingPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 25.03.2026.
//

import Foundation

struct EditMeetingInitialData {
    let companyId: Int
    let eventId: Int
    let title: String
    let startDate: Date
    let address: String
    let description: String
}

struct EditMeetingPrefillViewModel {
    let title: String
    let dateText: String
    let timeText: String
    let address: String
    let description: String
    let startDate: Date
}

protocol EditMeetingPresenterProtocol: AnyObject {
    func presentInitialData(_ viewModel: EditMeetingPrefillViewModel)
    func presentSuccess()
    func presentError(message: String)
}

final class EditMeetingPresenter: EditMeetingPresenterProtocol {
    weak var vc: EditMeetingVC?

    func presentInitialData(_ viewModel: EditMeetingPrefillViewModel) {
        DispatchQueue.main.async { [weak vc] in
            vc?.applyInitialData(viewModel)
        }
    }

    func presentSuccess() {
        DispatchQueue.main.async { [weak vc] in
            vc?.showSuccessAndClose()
        }
    }

    func presentError(message: String) {
        DispatchQueue.main.async { [weak vc] in
            vc?.showError(message: message)
        }
    }
}
