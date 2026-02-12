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
        guard let url = URL(string: "http://localhost:8000/companies") else {
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

        return try Self.decoder.decode([Company].self, from: data)
    }
}
