//  CompanyMembersWorker.swift
//  Sovpalo

import Foundation

// MARK: - Models

struct CompanyMemberView: Decodable {
    let userID: Int
    let username: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case userID   = "user_id"
        case username
        case role
    }
}

// MARK: - Errors

enum CompanyMembersWorkerError: Error, LocalizedError {
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

protocol CompanyMembersWorkerProtocol {
    /// GET /companies/:id/members
    func fetchMembers(companyID: Int) async throws -> [CompanyMemberView]
}

// MARK: - Implementation

final class CompanyMembersWorker: CompanyMembersWorkerProtocol {

    private let baseURL: URL
    private let urlSession: URLSession
    private let keychain: KeychainLogic

    init(
        baseURL: URL = URL(string: "http://localhost:8000")!,
        urlSession: URLSession = .shared,
        keychain: KeychainLogic = KeychainService()
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.keychain = keychain
    }

    func fetchMembers(companyID: Int) async throws -> [CompanyMemberView] {
        // 1) Token from Keychain
        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw CompanyMembersWorkerError.tokenNotFound
        }
        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw CompanyMembersWorkerError.tokenDecodingFailed
        }

        // 2) Build request — GET /companies/:id/members
        let endpoint = baseURL
            .appendingPathComponent("companies")
            .appendingPathComponent("\(companyID)")
            .appendingPathComponent("members")

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
            throw CompanyMembersWorkerError.badStatus(code: code)
        }

        // 5) Decode
        return try JSONDecoder().decode([CompanyMemberView].self, from: data)
    }
}
