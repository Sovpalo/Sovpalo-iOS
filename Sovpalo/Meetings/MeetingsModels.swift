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
