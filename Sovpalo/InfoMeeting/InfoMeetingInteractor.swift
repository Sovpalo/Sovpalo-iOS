//
//  InfoMeetingInteractor.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 24.03.2026.
//

import Foundation
import UIKit

protocol InfoMeetingBusinessLogic {
    func loadMeeting()
    func didTapEdit()
    func didTapUseRecommendation()
    func deleteMeeting()
    func loadMeetingImage(from photoURL: String, targetSize: CGSize) async -> UIImage?
}

final class InfoMeetingInteractor: InfoMeetingBusinessLogic {
    var presenter: InfoMeetingPresenterProtocol?
    var worker: InfoMeetingWorkerProtocol?

    private let companyId: Int
    private let meetingId: Int
    private let initialMeeting: Meeting?
    private var editInitialData: EditMeetingInitialData?
    private var recommendation: MeetingSuccessRecommendation?
    private var predictor: MeetingSuccessPredictor?

    init(companyId: Int, meetingId: Int, initialMeeting: Meeting?) {
        self.companyId = companyId
        self.meetingId = meetingId
        self.initialMeeting = initialMeeting
    }

    func loadMeeting() {
        if let initialMeeting {
            presenter?.presentMeeting(makeViewModel(from: initialMeeting))
        }

        guard let worker else {
            presenter?.presentError("Worker is unavailable")
            return
        }

        Task {
            do {
                async let eventDTO = worker.fetchCompanyEvent(companyId: companyId, eventId: meetingId)
                async let summaryDTO = worker.fetchAttendanceSummary(companyId: companyId, eventId: meetingId)

                let (event, summary) = try await (eventDTO, summaryDTO)
                let meeting = mapMeeting(dto: event, summary: summary)
                editInitialData = makeEditInitialData(from: event)
                let mlViewModel = try? await makeMLViewModel(event: event, summary: summary)
                presenter?.presentMeeting(makeViewModel(from: meeting, ml: mlViewModel))
            } catch {
                presenter?.presentError(error.localizedDescription)
            }
        }
    }

    func didTapEdit() {
        guard let editInitialData else {
            presenter?.presentError("Данные встречи еще загружаются")
            return
        }

        presenter?.routeToEditMeeting(initialData: editInitialData)
    }

    func didTapUseRecommendation() {
        guard let editInitialData else {
            presenter?.presentError("Данные встречи еще загружаются")
            return
        }
        guard let recommendation else {
            presenter?.presentError("Рекомендация пока недоступна")
            return
        }

        let updated = EditMeetingInitialData(
            companyId: editInitialData.companyId,
            eventId: editInitialData.eventId,
            title: editInitialData.title,
            startDate: recommendation.startDate,
            endDate: recommendation.endDate,
            address: editInitialData.address,
            description: editInitialData.description,
            photoURL: editInitialData.photoURL
        )
        presenter?.routeToEditMeeting(initialData: updated)
    }
    
    func deleteMeeting() {
        guard let worker else {
            presenter?.presentError("Worker is unavailable")
            return
        }

        Task {
            do {
                try await worker.deleteEvent(companyId: self.companyId, eventId: meetingId)
                await MainActor.run {
                    AppMetricaService.reportEvent(
                        AppMetricaEvent.meetingDeleted,
                        parameters: [
                            "screen": "InfoMeeting",
                            "company_id": self.companyId,
                            "meeting_id": self.meetingId
                        ]
                    )
                    NotificationCenter.default.post(name: .meetingDeleted, object: nil)
                    self.presenter?.routeBackAfterDelete()
                }
            } catch {
                await MainActor.run {
                    self.presenter?.presentError(error.localizedDescription)
                }
            }
        }
    }

    func loadMeetingImage(from photoURL: String, targetSize: CGSize) async -> UIImage? {
        guard let worker else { return nil }
        return await worker.fetchImage(from: photoURL, targetSize: targetSize)
    }

    private func mapMeeting(dto: CompanyEventDTO, summary: EventAttendanceSummaryDTO) -> Meeting {
        let startDate = dto.startTime.flatMap {
            Self.isoParserWithFractional.date(from: $0) ?? Self.isoParser.date(from: $0)
        }

        let endDate = dto.endTime.flatMap {
            Self.isoParserWithFractional.date(from: $0) ?? Self.isoParser.date(from: $0)
        }

        let dateText: String = {
            guard let startDate else { return "—" }
            let start = Self.dateFormatter.string(from: startDate)
            guard let endDate else { return start }

            if Calendar.current.isDate(startDate, inSameDayAs: endDate) {
                return start
            }

            let end = Self.dateFormatter.string(from: endDate)
            return "\(start) - \(end)"
        }()
        let timeText: String = {
            guard let startDate else { return "—" }
            let start = Self.timeFormatter.string(from: startDate)
            if let endDate {
                let end = Self.timeFormatter.string(from: endDate)
                return "\(start)-\(end)"
            }
            return start
        }()

        let parsedDescription = splitDescription(dto.description)

        return Meeting(
            id: dto.id,
            title: dto.title,
            dateText: dateText,
            timeText: timeText,
            cityText: "",
            addressText: parsedDescription.address,
            descriptionText: parsedDescription.details,
            photoURL: dto.photoURL,
            attendeesGoing: summary.going,
            attendeesNotGoing: summary.notGoing,
            organizerName: nil,
            responseStatus: .none,
            isArchived: false
        )
    }

    private func makeViewModel(from meeting: Meeting, ml: InfoMeetingMLViewModel? = nil) -> InfoMeetingViewModel {
        let locationText: String = {
            if meeting.cityText.isEmpty { return meeting.addressText }
            return "\(meeting.cityText), \(meeting.addressText)"
        }()

        let titleText = [meeting.title, meeting.dateText]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0 != "—" }
            .joined(separator: " ")

        let descriptionText = meeting.descriptionText?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return InfoMeetingViewModel(
            title: titleText.isEmpty ? meeting.title : titleText,
            timeText: meeting.timeText,
            locationText: locationText.isEmpty ? "Адрес не указан" : locationText,
            photoURL: meeting.photoURL,
            goingPeople: meeting.attendeesGoing,
            notGoingPeople: meeting.attendeesNotGoing,
            descriptionText: (descriptionText?.isEmpty == false) ? descriptionText! : "Описание отсутствует",
            ml: ml
        )
    }

    private func splitDescription(_ description: String?) -> (address: String, details: String?) {
        guard let description else {
            return ("Адрес не указан", nil)
        }

        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ("Адрес не указан", nil)
        }

        let parts = trimmed.components(separatedBy: "\n\n")
        if let first = parts.first, first.hasPrefix("Адрес:") {
            let address = first.replacingOccurrences(of: "Адрес:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let details = parts.dropFirst().joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return (
                address.isEmpty ? "Адрес не указан" : address,
                details.isEmpty ? nil : details
            )
        }

        return ("Адрес не указан", trimmed)
    }

    private func makeEditInitialData(from dto: CompanyEventDTO) -> EditMeetingInitialData? {
        guard let startTime = dto.startTime else { return nil }
        guard let startDate = Self.isoParserWithFractional.date(from: startTime) ?? Self.isoParser.date(from: startTime) else {
            return nil
        }
        let endDate = dto.endTime.flatMap {
            Self.isoParserWithFractional.date(from: $0) ?? Self.isoParser.date(from: $0)
        } ?? startDate

        let parsedDescription = splitDescription(dto.description)

        return EditMeetingInitialData(
            companyId: companyId,
            eventId: dto.id,
            title: dto.title,
            startDate: startDate,
            endDate: endDate,
            address: parsedDescription.address == "Адрес не указан" ? "" : parsedDescription.address,
            description: parsedDescription.details ?? "",
            photoURL: dto.photoURL
        )
    }

    private func makeMLViewModel(event: CompanyEventDTO, summary: EventAttendanceSummaryDTO) async throws -> InfoMeetingMLViewModel {
        guard let worker else {
            return InfoMeetingMLViewModel(probability: nil, recommendationText: "ML недоступен: worker", canUseRecommendation: false)
        }

        async let membersTask = worker.fetchCompanyMembers(companyId: companyId)
        async let availabilityTask = worker.fetchCompanyAvailability(companyId: companyId)
        async let eventsTask = worker.fetchCompanyEvents(companyId: companyId)

        let (members, availability, events) = try await (membersTask, availabilityTask, eventsTask)

        let baseStart = parseDate(event.startTime) ?? Date()
        let baseEnd = parseDate(event.endTime) ?? Calendar.current.date(byAdding: .hour, value: 1, to: baseStart) ?? baseStart
        let busyIntervals = busyIntervals(from: events, excludingEventId: event.id)

        let baseFeatures = buildFeatures(
            title: event.title,
            address: splitDescription(event.description).address,
            startDate: baseStart,
            endDate: baseEnd,
            members: members,
            availability: availability,
            summary: summary
        )

        do {
            if predictor == nil { predictor = try MeetingSuccessPredictor() }
            guard let predictor else {
                return InfoMeetingMLViewModel(probability: nil, recommendationText: "ML недоступен: модель не инициализировалась", canUseRecommendation: false)
            }

            let currentP = try predictor.successProbability(features: baseFeatures)

            let recommendation = try predictor.bestRecommendation(
                baseFeatures: baseFeatures,
                baseProbability: currentP,
                baseStartDate: baseStart,
                isCandidateAllowed: { candidateStart, candidateEnd in
                    !self.overlapsAnyBusyInterval(startDate: candidateStart, endDate: candidateEnd, busy: busyIntervals)
                },
                scoreOverride: { candidateStart, candidateEnd, candidateCoreFeatures in
                    let recomputed = self.buildFeatures(
                        title: event.title,
                        address: self.splitDescription(event.description).address,
                        startDate: candidateStart,
                        endDate: candidateEnd,
                        members: members,
                        availability: availability,
                        summary: summary,
                        base: candidateCoreFeatures
                    )
                    return try predictor.successProbability(features: recomputed)
                }
            )
            self.recommendation = recommendation

            let recommendationText: String? = {
                guard let recommendation else { return nil }
                let baseDelta = recommendation.probability - currentP
                let deltaText = String(format: "%+.0f%%", baseDelta * 100)
                let dateText = Self.recommendationDateFormatter.string(from: recommendation.startDate)
                let timeText = Self.timeFormatter.string(from: recommendation.startDate)
                let absText = String(format: "%.0f%%", recommendation.probability * 100)
                return "\(dateText), \(timeText) → \(absText) (\(deltaText))"
            }()

            return InfoMeetingMLViewModel(probability: currentP, recommendationText: recommendationText, canUseRecommendation: recommendation != nil)
        } catch {
            self.recommendation = nil
            return InfoMeetingMLViewModel(probability: nil, recommendationText: "ML недоступен: \(error.localizedDescription)", canUseRecommendation: false)
        }
    }

    private func parseDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return Self.isoParserWithFractional.date(from: raw) ?? Self.isoParser.date(from: raw)
    }

    private func buildFeatures(
        title: String,
        address: String,
        startDate: Date,
        endDate: Date,
        members: [CompanyMemberView],
        availability: [UserAvailability],
        summary: EventAttendanceSummaryDTO,
        base: MeetingFeatures? = nil
    ) -> MeetingFeatures {
        let calendar = Calendar.current

        let weekday = calendar.component(.weekday, from: startDate) // 1..7, 1=Sun
        let dayOfWeek = Double(weekday - 1) // 0..6, 0=Sun
        let isWeekend = (weekday == 1 || weekday == 7) ? 1.0 : 0.0

        let hour = Double(calendar.component(.hour, from: startDate))

        let participantsCount = Double(max(0, members.count))
        let freeUsers = freeUserIDs(
            startDate: startDate,
            endDate: endDate,
            members: members,
            availability: availability
        )
        let freeParticipantsCount = Double(freeUsers.count)
        let freeRatio = participantsCount > 0 ? (freeParticipantsCount / participantsCount) : 0

        let confirmedCount = Double(summary.going.count)
        let declinedCount = Double(summary.notGoing.count)
        let pendingCount = Double(summary.unknown.count)

        let durationMinutes = max(0.0, endDate.timeIntervalSince(startDate) / 60.0)

        let startOfToday = calendar.startOfDay(for: Date())
        let startOfMeeting = calendar.startOfDay(for: startDate)
        let daysUntilMeeting = Double(calendar.dateComponents([.day], from: startOfToday, to: startOfMeeting).day ?? 0)

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasTitle = trimmedTitle.isEmpty ? 0.0 : 1.0
        let titleLength = Double(trimmedTitle.count)

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAddress = trimmedAddress.isEmpty || trimmedAddress == "Адрес не указан" ? 0.0 : 1.0

        if let base {
            return MeetingFeatures(
                hour: hour,
                dayOfWeek: dayOfWeek,
                isWeekend: isWeekend,
                participantsCount: base.participantsCount,
                freeParticipantsCount: freeParticipantsCount,
                freeRatio: freeRatio,
                confirmedCount: base.confirmedCount,
                declinedCount: base.declinedCount,
                pendingCount: base.pendingCount,
                durationMinutes: base.durationMinutes,
                daysUntilMeeting: daysUntilMeeting,
                hasTitle: base.hasTitle,
                titleLength: base.titleLength,
                hasAddress: base.hasAddress
            )
        }

        return MeetingFeatures(
            hour: hour,
            dayOfWeek: dayOfWeek,
            isWeekend: isWeekend,
            participantsCount: participantsCount,
            freeParticipantsCount: freeParticipantsCount,
            freeRatio: freeRatio,
            confirmedCount: confirmedCount,
            declinedCount: declinedCount,
            pendingCount: pendingCount,
            durationMinutes: durationMinutes,
            daysUntilMeeting: daysUntilMeeting,
            hasTitle: hasTitle,
            titleLength: titleLength,
            hasAddress: hasAddress
        )
    }

    private func freeUserIDs(
        startDate: Date,
        endDate: Date,
        members: [CompanyMemberView],
        availability: [UserAvailability]
    ) -> Set<Int> {
        let memberIDs = Set(members.map(\.userID))
        var free: Set<Int> = []

        for item in availability {
            guard memberIDs.contains(item.userID) else { continue }
            if item.startTime <= startDate && item.endTime >= endDate {
                free.insert(item.userID)
            }
        }
        return free
    }

    private func busyIntervals(from events: [CompanyEventDTO], excludingEventId: Int) -> [(start: Date, end: Date)] {
        let calendar = Calendar.current
        var intervals: [(Date, Date)] = []

        for e in events where e.id != excludingEventId {
            guard let start = parseDate(e.startTime) else { continue }
            let end = parseDate(e.endTime) ?? calendar.date(byAdding: .hour, value: 1, to: start) ?? start
            intervals.append((start, max(start, end)))
        }

        return intervals
    }

    private func overlapsAnyBusyInterval(
        startDate: Date,
        endDate: Date,
        busy: [(start: Date, end: Date)]
    ) -> Bool {
        let start = min(startDate, endDate)
        let end = max(startDate, endDate)

        for interval in busy {
            if start < interval.end && end > interval.start {
                return true
            }
        }
        return false
    }

    private static let isoParserWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let recommendationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEE, dd.MM"
        return formatter
    }()
}
