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
    private let keychain: KeychainLogic

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func fetchCompanyEvents(companyId: Int) async throws -> [CompanyEventDTO] {
        let request = try makeRequest(
            path: "http://localhost:8000/companies/\(companyId)/events",
            method: "GET"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        return try decoder.decode([CompanyEventDTO].self, from: data)
    }

    func fetchAttendanceSummary(companyId: Int, eventId: Int) async throws -> EventAttendanceSummaryDTO {
        let request = try makeRequest(
            path: "http://localhost:8000/companies/\(companyId)/events/\(eventId)/attendance/summary",
            method: "GET"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(EventAttendanceSummaryDTO.self, from: data)
    }

    func setAttendance(companyId: Int, eventId: Int, status: String) async throws {
        var request = try makeRequest(
            path: "http://localhost:8000/companies/\(companyId)/events/\(eventId)/attendance",
            method: "POST"
        )

        let payload = SetAttendancePayload(status: status)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: path) else {
            throw MeetingsWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw MeetingsWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw MeetingsWorkerError.tokenDecodingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if method != "GET" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MeetingsWorkerError.badServerResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw MeetingsWorkerError.badStatus(code: httpResponse.statusCode, message: message)
        }
    }
}
