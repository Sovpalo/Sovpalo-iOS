//
//  CacheModels.swift
//  Sovpalo
//
//  Created by Codex on 12.05.2026.
//

import Foundation
import SwiftData

@Model
final class CachedCompany {
    @Attribute(.unique) var id: Int
    var name: String
    var companyDescription: String?
    var avatarURL: String?
    var createdBy: Int
    var createdAt: Date
    var updatedAt: Date
    var cachedAt: Date

    init(
        id: Int,
        name: String,
        companyDescription: String?,
        avatarURL: String?,
        createdBy: Int,
        createdAt: Date,
        updatedAt: Date,
        cachedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.companyDescription = companyDescription
        self.avatarURL = avatarURL
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.cachedAt = cachedAt
    }

    convenience init(company: Company) {
        self.init(
            id: company.id,
            name: company.name,
            companyDescription: company.description,
            avatarURL: company.avatarURL,
            createdBy: company.createdBy,
            createdAt: company.createdAt,
            updatedAt: company.updatedAt
        )
    }

    func update(from company: Company, cachedAt: Date = Date()) {
        name = company.name
        companyDescription = company.description
        avatarURL = company.avatarURL
        createdBy = company.createdBy
        createdAt = company.createdAt
        updatedAt = company.updatedAt
        self.cachedAt = cachedAt
    }

    func toCompany() -> Company {
        Company(
            id: id,
            name: name,
            description: companyDescription,
            avatarURL: avatarURL,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class CachedSettingsProfile {
    @Attribute(.unique) var cacheKey: String
    var username: String
    var avatarURL: String?
    var cachedAt: Date

    init(
        cacheKey: String = CachedSettingsProfile.currentUserCacheKey,
        username: String,
        avatarURL: String?,
        cachedAt: Date = Date()
    ) {
        self.cacheKey = cacheKey
        self.username = username
        self.avatarURL = avatarURL
        self.cachedAt = cachedAt
    }

    func update(from profile: SettingsProfile, cachedAt: Date = Date()) {
        username = profile.username
        avatarURL = profile.avatarURL
        self.cachedAt = cachedAt
    }

    func toSettingsProfile() -> SettingsProfile {
        SettingsProfile(username: username, avatarURL: avatarURL)
    }

    static let currentUserCacheKey = "current-user"
}

@Model
final class CachedCompanyEvent {
    @Attribute(.unique) var cacheKey: String
    var id: Int
    var companyId: Int
    var title: String
    var eventDescription: String?
    var photoURL: String?
    var startTime: String?
    var endTime: String?
    var createdBy: Int?
    var cachedAt: Date

    init(
        id: Int,
        companyId: Int,
        title: String,
        eventDescription: String?,
        photoURL: String?,
        startTime: String?,
        endTime: String?,
        createdBy: Int?,
        cachedAt: Date = Date()
    ) {
        self.cacheKey = "\(companyId)-\(id)"
        self.id = id
        self.companyId = companyId
        self.title = title
        self.eventDescription = eventDescription
        self.photoURL = photoURL
        self.startTime = startTime
        self.endTime = endTime
        self.createdBy = createdBy
        self.cachedAt = cachedAt
    }

    convenience init(dto: CompanyEventDTO, fallbackCompanyId: Int) {
        self.init(
            id: dto.id,
            companyId: dto.companyId ?? fallbackCompanyId,
            title: dto.title,
            eventDescription: dto.description,
            photoURL: dto.photoURL,
            startTime: dto.startTime,
            endTime: dto.endTime,
            createdBy: dto.createdBy
        )
    }

    func update(from dto: CompanyEventDTO, fallbackCompanyId: Int, cachedAt: Date = Date()) {
        id = dto.id
        companyId = dto.companyId ?? fallbackCompanyId
        cacheKey = "\(companyId)-\(id)"
        title = dto.title
        eventDescription = dto.description
        photoURL = dto.photoURL
        startTime = dto.startTime
        endTime = dto.endTime
        createdBy = dto.createdBy
        self.cachedAt = cachedAt
    }

    func toDTO() -> CompanyEventDTO {
        CompanyEventDTO(
            id: id,
            title: title,
            description: eventDescription,
            photoURL: photoURL,
            startTime: startTime,
            endTime: endTime,
            companyId: companyId,
            createdBy: createdBy
        )
    }
}

@Model
final class CachedMeeting {
    @Attribute(.unique) var cacheKey: String
    var id: Int
    var companyId: Int
    var title: String
    var dateText: String
    var timeText: String
    var cityText: String
    var addressText: String
    var descriptionText: String?
    var photoURL: String?
    var attendeesGoingData: Data
    var attendeesNotGoingData: Data
    var organizerName: String?
    var responseStatusRaw: String
    var isArchived: Bool
    var cachedAt: Date

    init(
        meeting: Meeting,
        companyId: Int,
        cachedAt: Date = Date()
    ) {
        self.cacheKey = "\(companyId)-\(meeting.id)"
        self.id = meeting.id
        self.companyId = companyId
        self.title = meeting.title
        self.dateText = meeting.dateText
        self.timeText = meeting.timeText
        self.cityText = meeting.cityText
        self.addressText = meeting.addressText
        self.descriptionText = meeting.descriptionText
        self.photoURL = meeting.photoURL
        self.attendeesGoingData = (try? JSONEncoder().encode(meeting.attendeesGoing)) ?? Data()
        self.attendeesNotGoingData = (try? JSONEncoder().encode(meeting.attendeesNotGoing)) ?? Data()
        self.organizerName = meeting.organizerName
        self.responseStatusRaw = meeting.responseStatus.cacheRawValue
        self.isArchived = meeting.isArchived
        self.cachedAt = cachedAt
    }

    func update(from meeting: Meeting, cachedAt: Date = Date()) {
        title = meeting.title
        dateText = meeting.dateText
        timeText = meeting.timeText
        cityText = meeting.cityText
        addressText = meeting.addressText
        descriptionText = meeting.descriptionText
        photoURL = meeting.photoURL
        attendeesGoingData = (try? JSONEncoder().encode(meeting.attendeesGoing)) ?? Data()
        attendeesNotGoingData = (try? JSONEncoder().encode(meeting.attendeesNotGoing)) ?? Data()
        organizerName = meeting.organizerName
        responseStatusRaw = meeting.responseStatus.cacheRawValue
        isArchived = meeting.isArchived
        self.cachedAt = cachedAt
    }

    func toMeeting() -> Meeting {
        Meeting(
            id: id,
            title: title,
            dateText: dateText,
            timeText: timeText,
            cityText: cityText,
            addressText: addressText,
            descriptionText: descriptionText,
            photoURL: photoURL,
            attendeesGoing: (try? JSONDecoder().decode([String].self, from: attendeesGoingData)) ?? [],
            attendeesNotGoing: (try? JSONDecoder().decode([String].self, from: attendeesNotGoingData)) ?? [],
            organizerName: organizerName,
            responseStatus: MeetingResponseStatus(cacheRawValue: responseStatusRaw),
            isArchived: isArchived
        )
    }
}

@Model
final class CachedCompanyMember {
    @Attribute(.unique) var cacheKey: String
    var userID: Int
    var companyId: Int
    var username: String
    var role: String
    var avatarURL: String?
    var cachedAt: Date

    init(member: CompanyMemberView, companyId: Int, cachedAt: Date = Date()) {
        self.cacheKey = "\(companyId)-\(member.userID)"
        self.userID = member.userID
        self.companyId = companyId
        self.username = member.username
        self.role = member.role
        self.avatarURL = member.avatarURL
        self.cachedAt = cachedAt
    }

    func update(from member: CompanyMemberView, cachedAt: Date = Date()) {
        username = member.username
        role = member.role
        avatarURL = member.avatarURL
        self.cachedAt = cachedAt
    }

    func toCompanyMemberView() -> CompanyMemberView {
        CompanyMemberView(
            userID: userID,
            username: username,
            role: role,
            avatarURL: avatarURL
        )
    }
}

@Model
final class CachedUserAvailability {
    @Attribute(.unique) var cacheKey: String
    var id: Int
    var userID: Int
    var companyId: Int
    var startTime: Date
    var endTime: Date
    var note: String?
    var cachedAt: Date

    init(availability: UserAvailability, companyId: Int, cachedAt: Date = Date()) {
        self.cacheKey = "\(companyId)-\(availability.id)"
        self.id = availability.id
        self.userID = availability.userID
        self.companyId = availability.companyID ?? companyId
        self.startTime = availability.startTime
        self.endTime = availability.endTime
        self.note = availability.note
        self.cachedAt = cachedAt
    }

    func update(from availability: UserAvailability, fallbackCompanyId: Int, cachedAt: Date = Date()) {
        userID = availability.userID
        companyId = availability.companyID ?? fallbackCompanyId
        startTime = availability.startTime
        endTime = availability.endTime
        note = availability.note
        self.cachedAt = cachedAt
    }

    func toUserAvailability() -> UserAvailability {
        UserAvailability(
            id: id,
            userID: userID,
            companyID: companyId,
            startTime: startTime,
            endTime: endTime,
            note: note
        )
    }
}

extension MeetingResponseStatus {
    var cacheRawValue: String {
        switch self {
        case .none:
            return "none"
        case .going:
            return "going"
        case .notGoing:
            return "notGoing"
        case .createdByMe:
            return "createdByMe"
        }
    }

    init(cacheRawValue: String) {
        switch cacheRawValue {
        case "going":
            self = .going
        case "notGoing":
            self = .notGoing
        case "createdByMe":
            self = .createdByMe
        default:
            self = .none
        }
    }
}
