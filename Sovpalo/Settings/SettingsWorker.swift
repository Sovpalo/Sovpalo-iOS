//
//  SettingsWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol SettingsWorkerProtocol {
    func fetchProfile() async throws -> SettingsProfile
}

enum SettingsWorkerError: LocalizedError {
    case invalidURL
    case tokenNotFound
    case tokenDecodingFailed
    case invalidResponse
    case badStatus(code: Int)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный URL"
        case .tokenNotFound:
            return "Не найден токен авторизации"
        case .tokenDecodingFailed:
            return "Не удалось прочитать токен авторизации"
        case .invalidResponse:
            return "Некорректный ответ сервера"
        case .badStatus(let code):
            return "Ошибка сервера. Код: \(code)"
        case .decodingFailed:
            return "Не удалось прочитать профиль пользователя"
        }
    }
}

final class SettingsWorker: SettingsWorkerProtocol {
    private let baseURL: URL?
    private let session: URLSession
    private let keychain: KeychainLogic

    init(
        baseURL: URL? = URL(string: "http://localhost:8000"),
        session: URLSession = .shared,
        keychain: KeychainLogic = KeychainService()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.keychain = keychain
    }

    func fetchProfile() async throws -> SettingsProfile {
        guard let baseURL else {
            throw SettingsWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw SettingsWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw SettingsWorkerError.tokenDecodingFailed
        }

        let url = baseURL.appendingPathComponent("auth/me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SettingsWorkerError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw SettingsWorkerError.badStatus(code: httpResponse.statusCode)
        }

        do {
            let user = try JSONDecoder().decode(SettingsCurrentUserDTO.self, from: data)
            return SettingsProfile(username: user.username)
        } catch {
            throw SettingsWorkerError.decodingFailed
        }
    }
}

private struct SettingsCurrentUserDTO: Decodable {
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
