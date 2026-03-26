//
//  userAvailabilityWorker.swift
//  Sovpalo
//
//  Created by Jovana on 23.3.26.
//

//  UserAvailabilityWorker.swift
//  Sovpalo

import Foundation

// MARK: - Errors

enum UserAvailabilityWorkerError: Error, LocalizedError {
    case tokenNotFound
    case tokenDecodingFailed
    case badStatus(code: Int)

    var errorDescription: String? {
        switch self {
        case .tokenNotFound:         return "Auth token not found"
        case .tokenDecodingFailed:   return "Failed to decode auth token"
        case .badStatus(let code):   return "HTTP error: \(code)"
        }
    }
}

// MARK: - Protocol

protocol UserAvailabilityWorkerProtocol {
    /// GET /companies/:id/availability — current user's own intervals
    func fetchMyAvailability(companyID: Int) async throws -> [UserAvailability]
    /// POST /companies/:id/availability
    func createAvailability(companyID: Int, startTime: Date, endTime: Date) async throws -> Int
    /// DELETE /companies/:id/availability/:availability_id
    func deleteAvailability(companyID: Int, availabilityID: Int) async throws
}

// MARK: - Implementation

final class UserAvailabilityWorker: UserAvailabilityWorkerProtocol {

    private let baseURL: URL?
    private let urlSession: URLSession
    private let keychain: KeychainLogic

    init(
        baseURL: URL? = URL(string: "http://localhost:8000"),
        urlSession: URLSession = .shared,
        keychain: KeychainLogic = KeychainService()
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.keychain = keychain
    }

    func fetchMyAvailability(companyID: Int) async throws -> [UserAvailability] {
        let request = try makeRequest(
            path: "companies/\(companyID)/availability",
            method: "GET"
        )
        let (data, response) = try await urlSession.data(for: request)
        try validate(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let result = try? decoder.decode([UserAvailability].self, from: data) {
            return result
        }
        return []
    }

    func createAvailability(companyID: Int, startTime: Date, endTime: Date) async throws -> Int {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone.current  // ← add this line
        let body: [String: String] = [
            "start_time": formatter.string(from: startTime),
            "end_time":   formatter.string(from: endTime)
        ]
       
        var request = try makeRequest(
            path: "companies/\(companyID)/availability",
            method: "POST"
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await urlSession.data(for: request)
        try validate(response)

        let decoded = try JSONDecoder().decode([String: Int].self, from: data)
        return decoded["id"] ?? -1
    }

    func deleteAvailability(companyID: Int, availabilityID: Int) async throws {
        let request = try makeRequest(
            path: "companies/\(companyID)/availability/\(availabilityID)",
            method: "DELETE"
        )
        let (_, response) = try await urlSession.data(for: request)
        try validate(response)
    }

    // MARK: - Helpers

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let tokenData = keychain.getData(forKey: "auth.token"),
              let token = String(data: tokenData, encoding: .utf8) else {
            throw UserAvailabilityWorkerError.tokenNotFound
        }
        guard let baseURL = baseURL else {
            throw UserAvailabilityWorkerError.badStatus(code: -1)
        }
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw UserAvailabilityWorkerError.badStatus(code: code)
        }
    }
}

