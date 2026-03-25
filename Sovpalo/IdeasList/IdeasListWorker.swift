//
//  IdeasListWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 26.03.2026.
//

import Foundation

enum IdeasListWorkerError: LocalizedError {
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

protocol IdeasListWorkerProtocol {
    func fetchIdeas(companyId: Int) async throws -> [CompanyIdeaDTO]
    func likeIdea(companyId: Int, ideaId: Int) async throws
    func unlikeIdea(companyId: Int, ideaId: Int) async throws
}

final class IdeasListWorker: IdeasListWorkerProtocol {
    private let keychain: KeychainLogic
    private let baseURL: String = "http://localhost:8000"

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func fetchIdeas(companyId: Int) async throws -> [CompanyIdeaDTO] {
        let request = try makeRequest(
            path: baseURL + "/companies/\(companyId)/ideas",
            method: "GET"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        // Gracefully handle empty or nullable responses from backend
        if data.isEmpty {
            return []
        }
        if let body = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           body.isEmpty || body == "null" {
            return []
        }

        let decoder = JSONDecoder()
        return try decoder.decode([CompanyIdeaDTO].self, from: data)
    }

    func likeIdea(companyId: Int, ideaId: Int) async throws {
        try await performIdeaLikeRequest(
            companyId: companyId,
            ideaId: ideaId,
            method: "POST"
        )
    }

    func unlikeIdea(companyId: Int, ideaId: Int) async throws {
        try await performIdeaLikeRequest(
            companyId: companyId,
            ideaId: ideaId,
            method: "DELETE"
        )
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: path) else {
            throw IdeasListWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw IdeasListWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw IdeasListWorkerError.tokenDecodingFailed
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
            throw IdeasListWorkerError.badServerResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw IdeasListWorkerError.badStatus(code: httpResponse.statusCode, message: message)
        }
    }

    private func performIdeaLikeRequest(companyId: Int, ideaId: Int, method: String) async throws {
        let candidatePaths = [
            baseURL + "/companies/\(companyId)/ideas/\(ideaId)/like",
            baseURL + "/companies/\(companyId)/ideas/\(ideaId)/likes"
        ]

        var lastError: Error?

        for path in candidatePaths {
            do {
                let request = try makeRequest(path: path, method: method)
                let (data, response) = try await URLSession.shared.data(for: request)
                try validate(response: response, data: data)
                return
            } catch let IdeasListWorkerError.badStatus(code, message)
                where code == 404 && message.lowercased().contains("page not found") {
                lastError = IdeasListWorkerError.badStatus(code: code, message: message)
                continue
            } catch {
                throw error
            }
        }

        throw lastError ?? IdeasListWorkerError.badStatus(code: 404, message: "404 page not found")
    }
}

struct CompanyIdeaDTO: Decodable {
    let id: Int
    let title: String
    let description: String?
    let authorName: String
    let likesCount: Int
    let isLiked: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        id = try container.decode(Int.self, forKeys: ["id"])
        title = try container.decodeIfPresent(String.self, forKeys: ["title", "name"]) ?? "Без названия"
        description = try container.decodeIfPresent(String.self, forKeys: ["description", "text", "content"])
        authorName = try container.decodeIfPresent(String.self, forKeys: [
            "author_name",
            "created_by_name",
            "created_by_username",
            "creator_name",
            "user_name",
            "author"
        ]) ?? "Автор неизвестен"
        likesCount = try container.decodeIfPresent(Int.self, forKeys: [
            "likes_count",
            "like_count",
            "likes"
        ]) ?? 0
        isLiked = try container.decodeIfPresent(Bool.self, forKeys: [
            "is_liked",
            "liked",
            "isLiked"
        ]) ?? false
    }
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }
}

private extension KeyedDecodingContainer where K == AnyCodingKey {
    func decode<T: Decodable>(_ type: T.Type, forKeys keys: [String]) throws -> T {
        for key in keys {
            let codingKey = AnyCodingKey(key)
            if let value = try decodeIfPresent(type, forKey: codingKey) {
                return value
            }
        }

        throw DecodingError.keyNotFound(
            AnyCodingKey(keys[0]),
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Missing keys: " + keys.joined(separator: ", ")
            )
        )
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKeys keys: [String]) throws -> T? {
        for key in keys {
            let codingKey = AnyCodingKey(key)
            if let value = try decodeIfPresent(type, forKey: codingKey) {
                return value
            }
        }

        return nil
    }
}
