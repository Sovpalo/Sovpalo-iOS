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
    func presentMembers(_ members: [CompanyMemberView])
    func presentError(_ error: Error)
}

final class GroupMembersPresenter: GroupMembersPresenterProtocol {
    weak var view: GroupMembersDisplayLogic?

    func presentMembers(_ members: [CompanyMemberView]) {
        let memberViewModels = members.map {
            GroupMembersModels.MemberViewModel(
                userID: $0.userID,
                name: $0.username,
                avatarLetter: String($0.username.prefix(1)).uppercased()
            )
        }
        view?.displayMembers(memberViewModels)
    }

    func presentError(_ error: Error) {
        view?.displayError(error.localizedDescription)
    }
}
