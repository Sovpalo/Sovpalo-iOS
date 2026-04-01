//
//  GroupMembersModels.swift
//  Sovpalo
//
//  Created by Jovana on 31.3.26.
//

//  GroupMembersModels.swift
//  Sovpalo

import Foundation

enum GroupMembersModels {
    struct ViewModel {
        let groupName: String
        let membersCount: String
        let avatarLetter: String
        let members: [MemberViewModel]
    }

    struct MemberViewModel {
        let userID: Int
        let name: String
        let avatarLetter: String
    }
}
