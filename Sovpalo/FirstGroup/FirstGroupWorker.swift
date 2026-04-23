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
        guard let url = URL(string: Server.url + "/companies") else {
            throw FirstGroupWorkerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[FirstGroupWorker] GET /companies failed, status=\(code), body=\(body)")
            throw FirstGroupWorkerError.badStatus(code: code, message: body)
        }

        if http.statusCode == 204 || data.isEmpty {
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
        guard let url = URL(string: Server.url + "/auth/me") else {
            throw FirstGroupWorkerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[FirstGroupWorker] GET /auth/me failed, status=\(code), body=\(body)")
            throw FirstGroupWorkerError.badStatus(code: code, message: body)
        }

        let profile = try JSONDecoder().decode(FirstGroupUserProfileDTO.self, from: data)
        return profile.username
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
