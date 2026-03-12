//
//  Models.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import Foundation

// MARK: - Domain model
struct Invitation {
    let id: Int
    let companyId: Int
    let companyName: String
    let invitedBy: Int
    let invitedByUsername: String
    let status: String
    let createdAt: String
}

// MARK: - Scene models
enum InvitationModels {
    enum Load {
        struct Request { }
        struct Response {
            let invitations: [Invitation]
        }
        struct ViewModel {
            let invitations: [Invitation]
        }
    }

    enum Accept {
        struct Request {
            let invitationId: Int
        }
        struct Response {
            let invitationId: Int
        }
        struct ViewModel {
            let invitationId: Int
        }
    }

    enum Decline {
        struct Request {
            let invitationId: Int
        }
        struct Response {
            let invitationId: Int
        }
        struct ViewModel {
            let invitationId: Int
        }
    }

    enum Error {
        struct Response {
            let message: String
            let invitationId: Int?
        }

        struct ViewModel {
            let message: String
            let invitationId: Int?
        }
    }
}

// MARK: - DTO
struct InvitationDTO: Decodable {
    let id: Int
    let companyId: Int
    let companyName: String
    let invitedBy: Int
    let invitedByUsername: String
    let status: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case companyId = "company_id"
        case companyName = "company_name"
        case invitedBy = "invited_by"
        case invitedByUsername = "invited_by_username"
        case status
        case createdAt = "created_at"
    }

    func toDomain() -> Invitation {
        Invitation(
            id: id,
            companyId: companyId,
            companyName: companyName,
            invitedBy: invitedBy,
            invitedByUsername: invitedByUsername,
            status: status,
            createdAt: createdAt
        )
    }
}

struct StatusResponseDTO: Decodable {
    let status: String
}
