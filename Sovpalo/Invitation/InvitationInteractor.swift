//
//  InvitationInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import Foundation

protocol InvitationBusinessLogic {
    func loadInvitations(request: InvitationModels.Load.Request)
    func acceptInvitation(request: InvitationModels.Accept.Request)
    func declineInvitation(request: InvitationModels.Decline.Request)
}

final class InvitationInteractor: InvitationBusinessLogic {
    var presenter: InvitationPresentationLogic?
    var worker: InvitationWorkerProtocol?
    private var invitations: [Invitation] = []

    func loadInvitations(request: InvitationModels.Load.Request) {
        Task {
            do {
                guard let worker else { return }
                let invitations = try await worker.fetchInvitations()
                self.invitations = invitations
                let response = InvitationModels.Load.Response(invitations: invitations)
                await MainActor.run {
                    presenter?.presentInvitations(response)
                }
            } catch {
                await MainActor.run {
                    presenter?.presentError(
                        InvitationModels.Error.Response(
                            message: error.localizedDescription,
                            invitationId: nil
                        )
                    )
                }
            }
        }
    }

    func acceptInvitation(request: InvitationModels.Accept.Request) {
        Task {
            do {
                guard let worker else { return }
                try await worker.acceptInvitation(id: request.invitationId)
                let response = InvitationModels.Accept.Response(invitationId: request.invitationId)
                await MainActor.run {
                    let invitation = self.invitations.first(where: { $0.id == request.invitationId })
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.companyInvitationAccepted,
                        parameters: [
                            "screen": "Invitation",
                            "invitation_id": request.invitationId,
                            "company_id": invitation?.companyId
                        ]
                    )
                    presenter?.presentAcceptedInvitation(response)
                }
            } catch {
                await MainActor.run {
                    presenter?.presentError(
                        InvitationModels.Error.Response(
                            message: error.localizedDescription,
                            invitationId: request.invitationId
                        )
                    )
                }
            }
        }
    }

    func declineInvitation(request: InvitationModels.Decline.Request) {
        Task {
            do {
                guard let worker else { return }
                try await worker.declineInvitation(id: request.invitationId)
                let response = InvitationModels.Decline.Response(invitationId: request.invitationId)
                await MainActor.run {
                    presenter?.presentDeclinedInvitation(response)
                }
            } catch {
                await MainActor.run {
                    presenter?.presentError(
                        InvitationModels.Error.Response(
                            message: error.localizedDescription,
                            invitationId: request.invitationId
                        )
                    )
                }
            }
        }
    }
}
