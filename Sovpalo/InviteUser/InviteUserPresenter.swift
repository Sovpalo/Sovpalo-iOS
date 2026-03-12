//
//  InviteUserPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.03.2026.
//

import Foundation

protocol InviteUserPresenterProtocol: AnyObject {
    func presentInviteSuccess(_ response: InviteUserModels.InviteResponse)
    func presentInviteError(_ error: Error)
}

final class InviteUserPresenter: InviteUserPresenterProtocol {
    weak var vc: InviteUserVC?

    func presentInviteSuccess(_ response: InviteUserModels.InviteResponse) {
        vc?.displayInviteSuccess(response)
    }
    
    func presentInviteError(_ error: Error) {
        vc?.displayInviteError(error)
    }
}
