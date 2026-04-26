//
//  Models.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import Foundation

struct Meeting {
    let id: Int
    let title: String
    let dateText: String
    let timeText: String
    let cityText: String
    let addressText: String
    let descriptionText: String?
    let photoURL: String?
    let attendeesGoing: [String]
    let attendeesNotGoing: [String]
    let organizerName: String?
    var responseStatus: MeetingResponseStatus
    let isArchived: Bool
}

enum MeetingResponseStatus {
    case none
    case going
    case notGoing
    case createdByMe
}

struct CompanyEventDTO: Decodable {
    let id: Int
    let title: String
    let description: String?
    let photoURL: String?
    let startTime: String?
    let endTime: String?
    let companyId: Int?
    let createdBy: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case photoURL = "photo_url"
        case startTime = "start_time"
        case endTime = "end_time"
        case companyId = "company_id"
        case createdBy = "created_by"
    }
}


struct EventAttendanceSummaryDTO: Decodable {
    let going: [String]
    let notGoing: [String]
    let unknown: [String]

    enum CodingKeys: String, CodingKey {
        case going
        case notGoing = "not_going"
        case unknown
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        going = try container.decodeIfPresent([String].self, forKey: .going) ?? []
        notGoing = try container.decodeIfPresent([String].self, forKey: .notGoing) ?? []
        unknown = try container.decodeIfPresent([String].self, forKey: .unknown) ?? []
    }
}

struct SetAttendancePayload: Encodable {
    let status: String
}
