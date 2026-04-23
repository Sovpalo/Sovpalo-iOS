//
//  MyGroupPresenter.swift
//  Sovpalo
//
//  Created by Jovana on 24.3.26.
//

//  GroupMembersPresenter.swift
//  Sovpalo

import Foundation

protocol GroupMembersPresenterProtocol: AnyObject {
    func presentMembers(_ members: [CompanyMemberView], currentUserID: Int?)
    func presentError(_ error: Error)
}

final class GroupMembersPresenter: GroupMembersPresenterProtocol {
    weak var view: GroupMembersDisplayLogic?

    func presentMembers(_ members: [CompanyMemberView], currentUserID: Int?) {
        let currentUserID = currentUserID ?? -1
        let isCurrentUserOwner = members.contains {
            $0.userID == currentUserID && isOwner(role: $0.role)
        }

        let memberViewModels = members.map {
            GroupMembersModels.MemberViewModel(
                userID: $0.userID,
                name: $0.username,
                avatarLetter: String($0.username.prefix(1)).uppercased(),
                avatarURL: $0.avatarURL,
                canBeRemoved: isCurrentUserOwner && $0.userID != currentUserID,
                isOwner: isOwner(role: $0.role)
            )
        }
        view?.displayMembers(memberViewModels)
    }

    func presentError(_ error: Error) {
        view?.displayError(error.localizedDescription)
    }

    private func isOwner(role: String) -> Bool {
        let normalizedRole = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedRole == "owner" || normalizedRole == "creator"
    }
}
