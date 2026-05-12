//
//  MeetingsWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import Foundation

enum MeetingsWorkerError: LocalizedError {
    case invalidURL
    case tokenNotFound
    case tokenDecodingFailed
    case badServerResponse
    case badStatus(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL"
        case .tokenNotFound:
            return "Не найден токен авторизации"
        case .tokenDecodingFailed:
            return "Не удалось прочитать токен авторизации"
        case .badServerResponse:
            return "Некорректный ответ сервера"
        case let .badStatus(code, message):
            return "Ошибка сервера (\(code)): \(message)"
        }
    }
}

protocol MeetingsWorkerProtocol {
    func fetchCompanyEvents(companyId: Int) async throws -> [CompanyEventDTO]
    func fetchAttendanceSummary(companyId: Int, eventId: Int) async throws -> EventAttendanceSummaryDTO
    func setAttendance(companyId: Int, eventId: Int, status: String) async throws
}

final class MeetingsWorker: MeetingsWorkerProtocol {
    private let network: any NetworkServicing

    init(
        keychain: KeychainLogic = KeychainService(),
        network: (any NetworkServicing)? = nil
    ) {
        self.network = network ?? NetworkService(keychain: keychain)
    }

    func fetchCompanyEvents(companyId: Int) async throws -> [CompanyEventDTO] {
        let data = try await network.data(
            path: "companies/\(companyId)/events",
            method: .get,
            authorized: true,
            body: nil,
            contentType: nil,
            headers: [:]
        )

        guard !data.isEmpty else {
            return []
        }

        if let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           body.isEmpty || body == "null" {
            return []
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        return try decoder.decode([CompanyEventDTO].self, from: data)
    }

    func fetchAttendanceSummary(companyId: Int, eventId: Int) async throws -> EventAttendanceSummaryDTO {
        try await network.decoded(
            path: "companies/\(companyId)/events/\(eventId)/attendance/summary",
            method: .get,
            authorized: true,
            decoder: JSONDecoder(),
            headers: [:]
        )
    }

    func setAttendance(companyId: Int, eventId: Int, status: String) async throws {
        _ = try await network.data(
            path: "companies/\(companyId)/events/\(eventId)/attendance",
            method: .post,
            authorized: true,
            body: try JSONEncoder().encode(SetAttendancePayload(status: status)),
            contentType: "application/json",
            headers: [:]
        )
    }
}
