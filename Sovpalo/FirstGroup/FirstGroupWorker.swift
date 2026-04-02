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
    let createdBy: Int
    let createdAt: Date
    let updatedAt: Date
}

// MARK: - Errors

enum FirstGroupWorkerError: Error {
    case invalidURL
    case badStatus(code: Int)
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
        // Настраиваем разбор ISO8601 с долями секунды: 2026-02-12T07:35:15.782688+07:00
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = iso.date(from: string) {
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
            throw FirstGroupWorkerError.badStatus(code: code)
        }

        if http.statusCode == 204 || data.isEmpty {
            return []
        }

        if let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           body.isEmpty || body == "null" {
            return []
        }

        return try Self.decoder.decode([Company].self, from: data)
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
            throw FirstGroupWorkerError.badStatus(code: code)
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
