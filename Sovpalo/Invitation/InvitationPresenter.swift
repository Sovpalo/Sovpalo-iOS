//
//  InvitationPresenter.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import Foundation

protocol InvitationPresentationLogic {
    func presentInvitations(_ response: InvitationModels.Load.Response)
    func presentAcceptedInvitation(_ response: InvitationModels.Accept.Response)
    func presentDeclinedInvitation(_ response: InvitationModels.Decline.Response)
    func presentError(_ response: InvitationModels.Error.Response)
}

final class InvitationPresenter: InvitationPresentationLogic {
    weak var vc: InvitationVC?

    func presentInvitations(_ response: InvitationModels.Load.Response) {
        let viewModel = InvitationModels.Load.ViewModel(invitations: response.invitations)
        vc?.displayInvitations(viewModel)
    }

    func presentAcceptedInvitation(_ response: InvitationModels.Accept.Response) {
        let viewModel = InvitationModels.Accept.ViewModel(invitationId: response.invitationId)
        vc?.displayAcceptedInvitation(viewModel)
    }

    func presentDeclinedInvitation(_ response: InvitationModels.Decline.Response) {
        let viewModel = InvitationModels.Decline.ViewModel(invitationId: response.invitationId)
        vc?.displayDeclinedInvitation(viewModel)
    }

    func presentError(_ response: InvitationModels.Error.Response) {
        let viewModel = InvitationModels.Error.ViewModel(
            message: response.message,
            invitationId: response.invitationId
        )
        vc?.displayError(viewModel)
    }
}
