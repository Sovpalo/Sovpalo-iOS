// InviteUserWorker.swift
// Sovpalo
//

import Foundation

protocol InviteUserWorkerProtocol {
    /// Отправляет приглашение на сервер
    /// - Parameters:
    ///   - username: Username друга
    ///   - companyId: ID компании
    /// - Throws: InviteUserWorkerError
    func invite(username: String, companyId: Int) async throws -> InviteUserModels.InviteResponse
}



final class InviteUserWorker: InviteUserWorkerProtocol {
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

    func invite(username: String, companyId: Int) async throws -> InviteUserModels.InviteResponse {
        print(">>> Inviting \(username) to companyId: \(companyId)")
        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw InviteUserWorkerError.tokenNotFound
        }
        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw InviteUserWorkerError.tokenNotFound
        }
        guard let baseURL = baseURL else { throw InviteUserWorkerError.unknown("Invalid base URL") }
        let endpoint = baseURL.appendingPathComponent("/companies/\(companyId)/invitations")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body = InviteUserModels.InviteUserRequestBody(username: username)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw InviteUserWorkerError.unknown("No HTTPURLResponse") }
        guard (200..<300).contains(http.statusCode) else {
            throw InviteUserWorkerError.badStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(InviteUserModels.InviteResponse.self, from: data)
        } catch {
            throw InviteUserWorkerError.decodingFailed
        }
    }
}

