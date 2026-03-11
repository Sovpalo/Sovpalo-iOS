//
//  InviteUserModels.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.03.2026.
//

enum InviteUserModels {
    struct InvitationPost {
        let username: String
        let status: Status

        enum Status {
            case sent, error
        }
    }
}
