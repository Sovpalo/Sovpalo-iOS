//
//  FirstGroupWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 12.02.2026.
//

import Foundation

// MARK: - Models

struct Company: Decodable {
    let id: Int
    let name: String
    let description: String?
    let avatarURL: String?
    let createdBy: Int
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Errors

enum FirstGroupWorkerError: Error, LocalizedError {
    case invalidURL
    case badStatus(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL"
        case let .badStatus(code, message):
            if !message.isEmpty {
                return readableMessage(from: message, fallbackCode: code)
            }
            return "Ошибка сервера (\(code))"
        }
    }

    private func readableMessage(from rawMessage: String, fallbackCode: Int) -> String {
        if let data = rawMessage.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = jsonObject["message"] as? String,
           !message.isEmpty {
            return message
        }

        let trimmed = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Ошибка сервера (\(fallbackCode))"
        }

        return trimmed
    }
}

protocol FirstGroupWorkerProtocol {
    /// Выполняет GET запрос за списком компаний, используя Bearer Token
    /// - Parameter token: Bearer token без префикса `Bearer `
    /// - Returns: Список компаний
    func GetCompaniesList(token: String) async throws -> [Company]
    func getCurrentUsername(token: String) async throws -> String
}

final class FirstGroupWorker: FirstGroupWorkerProtocol {

    // MARK: - Private

    private let network: any NetworkServicing

    init(network: (any NetworkServicing)? = nil) {
        self.network = network ?? NetworkService()
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let string = try container.decode(String.self)
            let formatterWithFractions = ISO8601DateFormatter()
            formatterWithFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatterWithFractions.date(from: string) {
                return date
            }

            let formatterWithoutFractions = ISO8601DateFormatter()
            formatterWithoutFractions.formatOptions = [.withInternetDateTime]
            if let date = formatterWithoutFractions.date(from: string) {
                return date
            }

            throw DecodingError.dataCorrupted(.init(codingPath: d.codingPath,
                                                    debugDescription: "Invalid ISO8601 date: \(string)"))
        }
        return decoder
    }()

    // MARK: - API

    func GetCompaniesList(token: String) async throws -> [Company] {
        let data = try await network.data(
            path: "companies",
            method: .get,
            authorized: false,
            body: nil,
            contentType: nil,
            headers: authorizationHeaders(token: token)
        )

        if data.isEmpty {
            return []
        }

        if let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           body.isEmpty || body == "null" {
            return []
        }

        let companies = try Self.decoder.decode([Company].self, from: data)
        print("[FirstGroupWorker] Decoded companies count: \(companies.count)")
        return companies
    }

    func getCurrentUsername(token: String) async throws -> String {
        let profile: FirstGroupUserProfileDTO = try await network.decoded(
            path: "auth/me",
            method: .get,
            authorized: false,
            decoder: JSONDecoder(),
            headers: authorizationHeaders(token: token)
        )
        return profile.username
    }

    private func authorizationHeaders(token: String) -> [String: String] {
        ["Authorization": "Bearer \(token)"]
    }
}

private struct FirstGroupUserProfileDTO: Decodable {
    let username: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        username = try container.decode(String.self, forKeys: [
            "username",
            "user_name",
            "name"
        ])
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
}
