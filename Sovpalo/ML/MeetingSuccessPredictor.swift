import Foundation
import CoreML

struct MeetingFeatures: Equatable {
    let hour: Double
    let dayOfWeek: Double
    let isWeekend: Double
    let participantsCount: Double
    let freeParticipantsCount: Double
    let freeRatio: Double
    let confirmedCount: Double
    let declinedCount: Double
    let pendingCount: Double
    let durationMinutes: Double
    let daysUntilMeeting: Double
    let hasTitle: Double
    let titleLength: Double
    let hasAddress: Double

    init(
        hour: Double,
        dayOfWeek: Double,
        isWeekend: Double,
        participantsCount: Double,
        freeParticipantsCount: Double,
        freeRatio: Double,
        confirmedCount: Double,
        declinedCount: Double,
        pendingCount: Double,
        durationMinutes: Double,
        daysUntilMeeting: Double,
        hasTitle: Double,
        titleLength: Double,
        hasAddress: Double
    ) {
        self.hour = hour
        self.dayOfWeek = dayOfWeek
        self.isWeekend = isWeekend
        self.participantsCount = participantsCount
        self.freeParticipantsCount = freeParticipantsCount
        self.freeRatio = freeRatio
        self.confirmedCount = confirmedCount
        self.declinedCount = declinedCount
        self.pendingCount = pendingCount
        self.durationMinutes = durationMinutes
        self.daysUntilMeeting = daysUntilMeeting
        self.hasTitle = hasTitle
        self.titleLength = titleLength
        self.hasAddress = hasAddress
    }

    func with(
        hour: Double,
        dayOfWeek: Double,
        isWeekend: Double,
        daysUntilMeeting: Double
    ) -> MeetingFeatures {
        MeetingFeatures(
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
}

struct MeetingSuccessRecommendation: Equatable {
    let startDate: Date
    let endDate: Date
    let probability: Double
}

enum MeetingSuccessPredictorError: LocalizedError {
    case modelNotFound
    case invalidPredictionOutput

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Не удалось найти ML модель MeetingSuccessClassifier"
        case .invalidPredictionOutput:
            return "Не удалось прочитать результат ML модели"
        }
    }
}

final class MeetingSuccessPredictor {
    private let model: MLModel

    init() throws {
        guard let modelURL = Bundle.main.url(forResource: "MeetingSuccessClassifier", withExtension: "mlmodelc") else {
            throw MeetingSuccessPredictorError.modelNotFound
        }
        model = try MLModel(contentsOf: modelURL)
    }

    func successProbability(features: MeetingFeatures) throws -> Double {
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "hour": features.hour,
            "day_of_week": features.dayOfWeek,
            "is_weekend": features.isWeekend,
            "participants_count": features.participantsCount,
            "free_participants_count": features.freeParticipantsCount,
            "free_ratio": features.freeRatio,
            "confirmed_count": features.confirmedCount,
            "declined_count": features.declinedCount,
            "pending_count": features.pendingCount,
            "duration_minutes": features.durationMinutes,
            "days_until_meeting": features.daysUntilMeeting,
            "has_title": features.hasTitle,
            "title_length": features.titleLength,
            "has_address": features.hasAddress
        ])

        let out = try model.prediction(from: provider)
        guard let probabilityValue = out.featureValue(for: "successProbability")?.dictionaryValue else {
            throw MeetingSuccessPredictorError.invalidPredictionOutput
        }

        if let num = probabilityValue[1] {
            return num.doubleValue
        }
        if let num = probabilityValue["1"] {
            return num.doubleValue
        }

        throw MeetingSuccessPredictorError.invalidPredictionOutput
    }

    func bestRecommendation(
        baseFeatures: MeetingFeatures,
        baseProbability: Double,
        baseStartDate: Date,
        searchDaysBefore: Int = 7,
        searchDaysAfter: Int = 14,
        hours: [Int] = Array(8...22),
        scoreOverride: ((_ startDate: Date, _ endDate: Date, _ candidateFeatures: MeetingFeatures) throws -> Double)? = nil
    ) throws -> MeetingSuccessRecommendation? {
        let calendar = Calendar.current

        let baseDaysUntil = Int(baseFeatures.daysUntilMeeting.rounded())
        let startOffset = max(0, baseDaysUntil - max(0, searchDaysBefore))
        let endOffset = max(startOffset, baseDaysUntil + max(0, searchDaysAfter))

        var best: MeetingSuccessRecommendation?

        for dayOffset in startOffset...endOffset {
            guard let dayDate = calendar.date(byAdding: .day, value: (dayOffset - baseDaysUntil), to: baseStartDate) else {
                continue
            }
            let weekday = calendar.component(.weekday, from: dayDate) // 1..7 where 1=Sunday
            let dayOfWeek = Double(weekday - 1) // 0..6 where 0=Sunday
            let isWeekend = (weekday == 1 || weekday == 7) ? 1.0 : 0.0

            for hour in hours {
                guard (0...23).contains(hour) else { continue }
                let candidateStart = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayDate) ?? dayDate
                let candidateEnd = calendar.date(byAdding: .minute, value: Int(baseFeatures.durationMinutes.rounded()), to: candidateStart) ?? candidateStart
                guard calendar.isDate(candidateStart, inSameDayAs: candidateEnd) else { continue }

                let features = baseFeatures.with(
                    hour: Double(hour),
                    dayOfWeek: dayOfWeek,
                    isWeekend: isWeekend,
                    daysUntilMeeting: Double(dayOffset)
                )

                let p: Double
                if let scoreOverride {
                    p = try scoreOverride(candidateStart, candidateEnd, features)
                } else {
                    p = try successProbability(features: features)
                }
                if p <= baseProbability { continue }

                if let currentBest = best, currentBest.probability >= p { continue }
                best = MeetingSuccessRecommendation(startDate: candidateStart, endDate: candidateEnd, probability: p)
            }
        }

        return best
    }
}
