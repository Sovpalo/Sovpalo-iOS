//  GroupAvailabilityWorker.swift
//  Sovpalo

import Foundation

// MARK: - Models

struct UserAvailability: Decodable {
    let id: Int
    let userID: Int
    let companyID: Int?
    let startTime: Date
    let endTime: Date
    let note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID    = "user_id"
        case companyID = "company_id"
        case startTime = "start_time"
        case endTime   = "end_time"
        case note
    }
}

// MARK: - Errors

enum GroupAvailabilityWorkerError: Error, LocalizedError {
    case invalidURL
    case tokenNotFound
    case tokenDecodingFailed
    case badStatus(code: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid URL"
        case .tokenNotFound:       return "Auth token not found"
        case .tokenDecodingFailed: return "Failed to decode auth token"
        case .badStatus(let code): return "HTTP error: \(code)"
        }
    }
}

// MARK: - Protocol

protocol GroupAvailabilityWorkerProtocol {
    /// GET /companies/:id/availability/all
    /// Returns availability intervals for all members of a company
    func fetchCompanyAvailability(companyID: Int) async throws -> [UserAvailability]
}

// MARK: - Implementation

final class GroupAvailabilityWorker: GroupAvailabilityWorkerProtocol {

    private let baseURL: URL?
    private let urlSession: URLSession
    private let keychain: KeychainLogic

    init(
        baseURL: URL? = URL(string: Server.url),
        urlSession: URLSession = .shared,
        keychain: KeychainLogic = KeychainService()
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.keychain = keychain
    }

    func fetchCompanyAvailability(companyID: Int) async throws -> [UserAvailability] {
        // 1) Token from Keychain
        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw GroupAvailabilityWorkerError.tokenNotFound
        }
        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw GroupAvailabilityWorkerError.tokenDecodingFailed
        }

        guard let baseURL = baseURL else {
            throw GroupAvailabilityWorkerError.invalidURL
        }

        // 2) Build request — GET /companies/:id/availability/all
        let endpoint = baseURL
            .appendingPathComponent("companies")
            .appendingPathComponent("\(companyID)")
            .appendingPathComponent("availability")
            .appendingPathComponent("all")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // 3) Fire request
        let (data, response) = try await urlSession.data(for: request)

        // 4) Validate status
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GroupAvailabilityWorkerError.badStatus(code: code)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let result = try? decoder.decode([UserAvailability].self, from: data) {
            return result
        } else {
            return [] // backend returned null, treat as empty
        }
    }
}
