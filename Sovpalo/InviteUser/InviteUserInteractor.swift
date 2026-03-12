//
//  InviteUserInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.03.2026.
//

import Foundation

protocol InviteUserBusinessLogic: AnyObject {
    var invitations: [InviteUserModels.InviteResponse] { get }
    func sendInvite(username: String) async
}

final class InviteUserInteractor: InviteUserBusinessLogic {
    var presenter: InviteUserPresenterProtocol?
    var worker: InviteUserWorkerProtocol?

    private let companyId: Int
    private(set) var invitations: [InviteUserModels.InviteResponse] = []

    init(companyId: Int) {
        self.companyId = companyId
    }

    func sendInvite(username: String) async {
        do {
            guard let response = try await worker?.invite(username: username, companyId: companyId) else {
                return
            }

            let responseForUI = InviteUserModels.InviteResponse(
                id: response.id,
                companyId: response.companyId,
                invitedUserId: response.invitedUserId,
                invitedBy: response.invitedBy,
                status: response.status,
                createdAt: response.createdAt,
                respondedAt: response.respondedAt,
                username: username
            )

            invitations.append(responseForUI)

            await MainActor.run {
                presenter?.presentInviteSuccess(responseForUI)
            }
        } catch {
            print("Invite error:", error)
            await MainActor.run {
                presenter?.presentInviteError(error)
            }
        }
    }
}
