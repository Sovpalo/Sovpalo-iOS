//
//  InviteUserModels.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.03.2026.
//

import Foundation

enum InviteUserModels {
    struct InvitationPost {
        let username: String
        let status: Status

        enum Status {
            case sent, error
        }
    }
    
    struct InviteResponse: Decodable {
        let id: Int
        let companyId: Int
        let invitedUserId: Int
        let invitedBy: Int?
        let status: String
        let createdAt: String
        let respondedAt: String?
        let username: String?

        enum CodingKeys: String, CodingKey {
            case id
            case companyId = "company_id"
            case invitedUserId = "invited_user_id"
            case invitedBy = "invited_by"
            case status
            case createdAt = "created_at"
            case respondedAt = "responded_at"
            case username
        }
    }
    
    struct InviteUserRequestBody: Codable {
        let username: String
    }
}

enum InviteUserWorkerError: Error, LocalizedError {
    case invalidURL
    case tokenNotFound
    case badStatus(Int)
    case decodingFailed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .tokenNotFound: return "Auth token not found"
        case .badStatus(let code): return "HTTP error: \(code)"
        case .decodingFailed: return "Unable to decode response"
        case .unknown(let msg): return msg
        }
    }
}
