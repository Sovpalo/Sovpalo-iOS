//
//  CreateIdeasPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import UIKit

protocol CreateIdeasPresenterProtocol {
    func presentSuccess()
    func presentError(message: String)
}

final class CreateIdeasPresenter: CreateIdeasPresenterProtocol {
    weak var vc: CreateIdeasVC?

    func presentSuccess() {
        vc?.showSuccessAndClose()
    }

    func presentError(message: String) {
        vc?.showError(message: message)
    }
}
