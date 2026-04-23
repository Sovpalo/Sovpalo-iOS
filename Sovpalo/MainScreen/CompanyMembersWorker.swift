//  CompanyMembersWorker.swift
//  Sovpalo

import Foundation

// MARK: - Models

struct CompanyMemberView: Decodable {
    let userID: Int
    let username: String
    let role: String
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case userID   = "user_id"
        case username
        case role
        case avatarURL = "avatar_url"
    }
}

// MARK: - Errors

enum CompanyMembersWorkerError: Error, LocalizedError {
    case tokenNotFound
    case tokenDecodingFailed
    case invalidURL
    case badStatus(code: Int)

    var errorDescription: String? {
        switch self {
        case .tokenNotFound:         return "Auth token not found"
        case .tokenDecodingFailed:   return "Failed to decode auth token"
        case .invalidURL:            return "Invalid URL"
        case .badStatus(let code):   return "HTTP error: \(code)"
        }
    }
}

// MARK: - Protocol

protocol CompanyMembersWorkerProtocol {
    /// GET /companies/:id/members
    func fetchMembers(companyID: Int) async throws -> [CompanyMemberView]
    /// DELETE /companies/:id/members/:user_id
    func removeMember(companyID: Int, userID: Int) async throws
}

// MARK: - Implementation

final class CompanyMembersWorker: CompanyMembersWorkerProtocol {

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

    func fetchMembers(companyID: Int) async throws -> [CompanyMemberView] {
        let request = try makeAuthorizedRequest(
            url: membersEndpoint(companyID: companyID),
            method: "GET"
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CompanyMembersWorkerError.badStatus(code: code)
        }

        return try JSONDecoder().decode([CompanyMemberView].self, from: data)
    }

    func removeMember(companyID: Int, userID: Int) async throws {
        let request = try makeAuthorizedRequest(
            url: membersEndpoint(companyID: companyID)
                .appendingPathComponent("\(userID)"),
            method: "DELETE"
        )

        let (_, response) = try await urlSession.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CompanyMembersWorkerError.badStatus(code: code)
        }
    }

    private func membersEndpoint(companyID: Int) throws -> URL {
        guard let baseURL = baseURL else {
            throw CompanyMembersWorkerError.invalidURL
        }

        return baseURL
            .appendingPathComponent("companies")
            .appendingPathComponent("\(companyID)")
            .appendingPathComponent("members")
    }

    private func makeAuthorizedRequest(url: URL, method: String) throws -> URLRequest {
        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw CompanyMembersWorkerError.tokenNotFound
        }
        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw CompanyMembersWorkerError.tokenDecodingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
