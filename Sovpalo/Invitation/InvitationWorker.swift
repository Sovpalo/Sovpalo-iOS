//
//  InvitationWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 11.03.2026.
//

import Foundation

protocol InvitationWorkerProtocol {
    func fetchInvitations() async throws -> [Invitation]
    func acceptInvitation(id: Int) async throws
    func declineInvitation(id: Int) async throws
}

enum InvitationWorkerError: LocalizedError {
    case invalidURL
    case unauthorized
    case badStatusCode(Int)
    case emptyToken

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL"
        case .unauthorized:
            return "Вы не авторизованы"
        case .badStatusCode(let code):
            return "Ошибка сервера. Код: \(code)"
        case .emptyToken:
            return "Не найден токен авторизации"
        }
    }
}

final class InvitationWorker: InvitationWorkerProtocol {
    private let baseURL: String
    private let session: URLSession
    private let tokenProvider: () -> String?

    init(
        baseURL: String,
        session: URLSession = .shared,
        tokenProvider: @escaping () -> String?
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func fetchInvitations() async throws -> [Invitation] {
        let request = try makeRequest(
            path: "/companies/invitations",
            method: "GET"
        )

        let (data, response) = try await session.data(for: request)
        let httpResponse = try validate(response: response)

        if httpResponse.statusCode == 204 || data.isEmpty {
            return []
        }

        if let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           body.isEmpty || body == "null" {
            return []
        }

        let dto = try JSONDecoder().decode([InvitationDTO].self, from: data)
        return dto.map { $0.toDomain() }
    }

    func acceptInvitation(id: Int) async throws {
        let request = try makeRequest(
            path: "/companies/invitations/\(id)/accept",
            method: "POST"
        )

        let (_, response) = try await session.data(for: request)
        _ = try validate(response: response)
    }

    func declineInvitation(id: Int) async throws {
        let request = try makeRequest(
            path: "/companies/invitations/\(id)/decline",
            method: "POST"
        )

        let (_, response) = try await session.data(for: request)
        _ = try validate(response: response)
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw InvitationWorkerError.invalidURL
        }

        guard let token = tokenProvider(), !token.isEmpty else {
            throw InvitationWorkerError.emptyToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func validate(response: URLResponse) throws -> HTTPURLResponse {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw InvitationWorkerError.badStatusCode(-1)
        }

        switch httpResponse.statusCode {
        case 200...299:
            return httpResponse
        case 401:
            throw InvitationWorkerError.unauthorized
        default:
            throw InvitationWorkerError.badStatusCode(httpResponse.statusCode)
        }
    }
}
