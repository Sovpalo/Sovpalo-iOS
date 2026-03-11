//
//  InviteUserInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.03.2026.
//

import Foundation

protocol InviteUserBusinessLogic {
    var invitations: [InviteUserModels.InvitationPost] { get }
    func sendInvite(username: String) -> InviteUserModels.InvitationPost.Status?
}

final class InviteUserInteractor: InviteUserBusinessLogic {
    var presenter: InviteUserPresenterProtocol?
    var worker: InviteUserWorkerProtocol?
    
    var invitations: [InviteUserModels.InvitationPost] = []
    
    func sendInvite(username: String) -> InviteUserModels.InvitationPost.Status? {
        if invitations.contains(where: { $0.username == username && $0.status == .sent }) {
            return nil
        }
        let status: InviteUserModels.InvitationPost.Status = Bool.random() ? .sent : .error
        invitations.append(InviteUserModels.InvitationPost(username: username, status: status))
        return status
    }
}

