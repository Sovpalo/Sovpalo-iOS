//
//  LocalCacheService.swift
//  Sovpalo
//
//  Created by Codex on 12.05.2026.
//

import Foundation
import SwiftData

@MainActor
final class LocalCacheService {
    static let shared = LocalCacheService()

    private let container: ModelContainer?

    init() {
        do {
            let schema = Schema([
                CachedCompany.self,
                CachedSettingsProfile.self,
                CachedCompanyEvent.self,
                CachedMeeting.self,
                CachedCompanyMember.self,
                CachedUserAvailability.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            print("[LocalCacheService] Failed to initialize SwiftData cache: \(error)")
            container = nil
        }
    }

    func fetchCompanies() -> [Company] {
        guard let context = makeContext() else { return [] }

        do {
            let descriptor = FetchDescriptor<CachedCompany>(
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            return try context.fetch(descriptor).map { $0.toCompany() }
        } catch {
            print("[LocalCacheService] Failed to fetch cached companies: \(error)")
            return []
        }
    }

    func saveCompanies(_ companies: [Company]) {
        guard let context = makeContext() else { return }

        do {
            let descriptor = FetchDescriptor<CachedCompany>()
            let cachedCompanies = try context.fetch(descriptor)
            let cachedById = Dictionary(uniqueKeysWithValues: cachedCompanies.map { ($0.id, $0) })
            let freshIds = Set(companies.map(\.id))
            let now = Date()

            for company in companies {
                if let cachedCompany = cachedById[company.id] {
                    cachedCompany.update(from: company, cachedAt: now)
                } else {
                    context.insert(CachedCompany(company: company))
                }
            }

            for cachedCompany in cachedCompanies where !freshIds.contains(cachedCompany.id) {
                context.delete(cachedCompany)
            }

            try context.save()
        } catch {
            print("[LocalCacheService] Failed to save cached companies: \(error)")
        }
    }

    func fetchSettingsProfile() -> SettingsProfile? {
        guard let context = makeContext() else { return nil }

        do {
            var descriptor = FetchDescriptor<CachedSettingsProfile>(
                predicate: #Predicate { profile in
                    profile.cacheKey == "current-user"
                }
            )
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.toSettingsProfile()
        } catch {
            print("[LocalCacheService] Failed to fetch cached settings profile: \(error)")
            return nil
        }
    }

    func saveSettingsProfile(_ profile: SettingsProfile) {
        guard let context = makeContext() else { return }

        do {
            var descriptor = FetchDescriptor<CachedSettingsProfile>(
                predicate: #Predicate { profile in
                    profile.cacheKey == "current-user"
                }
            )
            descriptor.fetchLimit = 1

            if let cachedProfile = try context.fetch(descriptor).first {
                cachedProfile.update(from: profile)
            } else {
                context.insert(CachedSettingsProfile(
                    username: profile.username,
                    avatarURL: profile.avatarURL
                ))
            }

            try context.save()
        } catch {
            print("[LocalCacheService] Failed to save cached settings profile: \(error)")
        }
    }

    func clearUserCache() {
        guard let context = makeContext() else { return }

        do {
            try context.delete(model: CachedCompany.self)
            try context.delete(model: CachedSettingsProfile.self)
            try context.delete(model: CachedCompanyEvent.self)
            try context.delete(model: CachedMeeting.self)
            try context.delete(model: CachedCompanyMember.self)
            try context.delete(model: CachedUserAvailability.self)
            try context.save()
        } catch {
            print("[LocalCacheService] Failed to clear user cache: \(error)")
        }
    }

    func fetchCompanyEvents(companyId: Int) -> [CompanyEventDTO] {
        guard let context = makeContext() else { return [] }

        do {
            let descriptor = FetchDescriptor<CachedCompanyEvent>(
                predicate: #Predicate { event in
                    event.companyId == companyId
                },
                sortBy: [SortDescriptor(\.id, order: .reverse)]
            )
            return try context.fetch(descriptor).map { $0.toDTO() }
        } catch {
            print("[LocalCacheService] Failed to fetch cached company events: \(error)")
            return []
        }
    }

    func saveCompanyEvents(_ events: [CompanyEventDTO], companyId: Int) {
        guard let context = makeContext() else { return }

        do {
            let descriptor = FetchDescriptor<CachedCompanyEvent>(
                predicate: #Predicate { event in
                    event.companyId == companyId
                }
            )
            let cachedEvents = try context.fetch(descriptor)
            let cachedById = Dictionary(uniqueKeysWithValues: cachedEvents.map { ($0.id, $0) })
            let freshIds = Set(events.map(\.id))
            let now = Date()

            for event in events {
                if let cachedEvent = cachedById[event.id] {
                    cachedEvent.update(from: event, fallbackCompanyId: companyId, cachedAt: now)
                } else {
                    context.insert(CachedCompanyEvent(dto: event, fallbackCompanyId: companyId))
                }
            }

            for cachedEvent in cachedEvents where !freshIds.contains(cachedEvent.id) {
                context.delete(cachedEvent)
            }

            try context.save()
        } catch {
            print("[LocalCacheService] Failed to save cached company events: \(error)")
        }
    }

    func fetchMeetings(companyId: Int) -> [Meeting] {
        guard let context = makeContext() else { return [] }

        do {
            let descriptor = FetchDescriptor<CachedMeeting>(
                predicate: #Predicate { meeting in
                    meeting.companyId == companyId
                },
                sortBy: [SortDescriptor(\.id, order: .reverse)]
            )
            return try context.fetch(descriptor).map { $0.toMeeting() }
        } catch {
            print("[LocalCacheService] Failed to fetch cached meetings: \(error)")
            return []
        }
    }

    func saveMeetings(_ meetings: [Meeting], companyId: Int) {
        guard let context = makeContext() else { return }

        do {
            let descriptor = FetchDescriptor<CachedMeeting>(
                predicate: #Predicate { meeting in
                    meeting.companyId == companyId
                }
            )
            let cachedMeetings = try context.fetch(descriptor)
            let cachedById = Dictionary(uniqueKeysWithValues: cachedMeetings.map { ($0.id, $0) })
            let freshIds = Set(meetings.map(\.id))
            let now = Date()

            for meeting in meetings {
                if let cachedMeeting = cachedById[meeting.id] {
                    cachedMeeting.update(from: meeting, cachedAt: now)
                } else {
                    context.insert(CachedMeeting(meeting: meeting, companyId: companyId))
                }
            }

            for cachedMeeting in cachedMeetings where !freshIds.contains(cachedMeeting.id) {
                context.delete(cachedMeeting)
            }

            try context.save()
        } catch {
            print("[LocalCacheService] Failed to save cached meetings: \(error)")
        }
    }

    func fetchMembers(companyId: Int) -> [CompanyMemberView] {
        guard let context = makeContext() else { return [] }

        do {
            let descriptor = FetchDescriptor<CachedCompanyMember>(
                predicate: #Predicate { member in
                    member.companyId == companyId
                },
                sortBy: [SortDescriptor(\.username, order: .forward)]
            )
            return try context.fetch(descriptor).map { $0.toCompanyMemberView() }
        } catch {
            print("[LocalCacheService] Failed to fetch cached members: \(error)")
            return []
        }
    }

    func saveMembers(_ members: [CompanyMemberView], companyId: Int) {
        guard let context = makeContext() else { return }

        do {
            let descriptor = FetchDescriptor<CachedCompanyMember>(
                predicate: #Predicate { member in
                    member.companyId == companyId
                }
            )
            let cachedMembers = try context.fetch(descriptor)
            let cachedById = Dictionary(uniqueKeysWithValues: cachedMembers.map { ($0.userID, $0) })
            let freshIds = Set(members.map(\.userID))
            let now = Date()

            for member in members {
                if let cachedMember = cachedById[member.userID] {
                    cachedMember.update(from: member, cachedAt: now)
                } else {
                    context.insert(CachedCompanyMember(member: member, companyId: companyId))
                }
            }

            for cachedMember in cachedMembers where !freshIds.contains(cachedMember.userID) {
                context.delete(cachedMember)
            }

            try context.save()
        } catch {
            print("[LocalCacheService] Failed to save cached members: \(error)")
        }
    }

    func fetchAvailability(companyId: Int) -> [UserAvailability] {
        guard let context = makeContext() else { return [] }

        do {
            let descriptor = FetchDescriptor<CachedUserAvailability>(
                predicate: #Predicate { availability in
                    availability.companyId == companyId
                },
                sortBy: [SortDescriptor(\.startTime, order: .forward)]
            )
            return try context.fetch(descriptor).map { $0.toUserAvailability() }
        } catch {
            print("[LocalCacheService] Failed to fetch cached availability: \(error)")
            return []
        }
    }

    func saveAvailability(_ availability: [UserAvailability], companyId: Int) {
        guard let context = makeContext() else { return }

        do {
            let descriptor = FetchDescriptor<CachedUserAvailability>(
                predicate: #Predicate { item in
                    item.companyId == companyId
                }
            )
            let cachedAvailability = try context.fetch(descriptor)
            let cachedById = Dictionary(uniqueKeysWithValues: cachedAvailability.map { ($0.id, $0) })
            let freshIds = Set(availability.map(\.id))
            let now = Date()

            for item in availability {
                if let cachedItem = cachedById[item.id] {
                    cachedItem.update(from: item, fallbackCompanyId: companyId, cachedAt: now)
                } else {
                    context.insert(CachedUserAvailability(availability: item, companyId: companyId))
                }
            }

            for cachedItem in cachedAvailability where !freshIds.contains(cachedItem.id) {
                context.delete(cachedItem)
            }

            try context.save()
        } catch {
            print("[LocalCacheService] Failed to save cached availability: \(error)")
        }
    }

    private func makeContext() -> ModelContext? {
        guard let container else { return nil }
        return ModelContext(container)
    }
}
