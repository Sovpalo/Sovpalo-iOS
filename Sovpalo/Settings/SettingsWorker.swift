//
//  SettingsWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 01.04.2026.
//

import Foundation

protocol SettingsWorkerProtocol {
    func fetchProfile() async throws -> SettingsProfile
    func fetchAvatarData(from avatarURL: String) async throws -> Data
    func uploadAvatar(imageData: Data, fileName: String, mimeType: String) async throws -> SettingsProfile
    func deleteAvatar() async throws -> SettingsProfile
}

enum SettingsWorkerError: LocalizedError {
    case invalidURL
    case tokenNotFound
    case tokenDecodingFailed
    case invalidResponse
    case badStatus(code: Int, message: String)
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
        case let .badStatus(_, message):
            return extractReadableMessage(from: message)
        case .decodingFailed:
            return "Не удалось прочитать профиль пользователя"
        }
    }

    private func extractReadableMessage(from rawMessage: String) -> String {
        if let data = rawMessage.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = jsonObject["message"] as? String,
           !message.isEmpty {
            return message
        }

        return rawMessage.isEmpty ? "Не удалось выполнить запрос" : rawMessage
    }
}

final class SettingsWorker: SettingsWorkerProtocol {
    private let baseURL: URL?
    private let session: URLSession
    private let keychain: KeychainLogic

    init(
        baseURL: URL? = URL(string: Server.url),
        session: URLSession = .shared,
        keychain: KeychainLogic = KeychainService()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.keychain = keychain
    }

    func fetchProfile() async throws -> SettingsProfile {
        let request = try authorizedRequest(path: "auth/me", method: "GET")
        let data = try await performDataRequest(request)

        do {
            let user = try JSONDecoder().decode(SettingsCurrentUserDTO.self, from: data)
            return SettingsProfile(
                username: user.username,
                avatarURL: user.avatarURL
            )
        } catch {
            throw SettingsWorkerError.decodingFailed
        }
    }

    func fetchAvatarData(from avatarURL: String) async throws -> Data {
        guard let baseURL else {
            throw SettingsWorkerError.invalidURL
        }

        let resolvedURL: URL
        if let absoluteURL = URL(string: avatarURL), absoluteURL.scheme != nil {
            resolvedURL = absoluteURL
        } else {
            resolvedURL = baseURL.appendingPathComponent(avatarURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        }

        var request = URLRequest(url: resolvedURL)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SettingsWorkerError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Не удалось загрузить аватар"
            throw SettingsWorkerError.badStatus(code: httpResponse.statusCode, message: message)
        }

        return data
    }

    func uploadAvatar(imageData: Data, fileName: String, mimeType: String) async throws -> SettingsProfile {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = try authorizedRequest(path: "auth/me/avatar", method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = makeMultipartBody(
            boundary: boundary,
            imageData: imageData,
            fileName: fileName,
            mimeType: mimeType
        )

        let data = try await performDataRequest(request)

        do {
            let user = try JSONDecoder().decode(SettingsCurrentUserDTO.self, from: data)
            return SettingsProfile(
                username: user.username,
                avatarURL: user.avatarURL
            )
        } catch {
            throw SettingsWorkerError.decodingFailed
        }
    }

    func deleteAvatar() async throws -> SettingsProfile {
        let request = try authorizedRequest(path: "auth/me/avatar", method: "DELETE")
        let data = try await performDataRequest(request)

        do {
            let user = try JSONDecoder().decode(SettingsCurrentUserDTO.self, from: data)
            return SettingsProfile(
                username: user.username,
                avatarURL: user.avatarURL
            )
        } catch {
            throw SettingsWorkerError.decodingFailed
        }
    }

    private func authorizedRequest(path: String, method: String) throws -> URLRequest {
        guard let baseURL else {
            throw SettingsWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw SettingsWorkerError.tokenNotFound
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw SettingsWorkerError.tokenDecodingFailed
        }

        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func performDataRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SettingsWorkerError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Ошибка сервера"
            throw SettingsWorkerError.badStatus(code: httpResponse.statusCode, message: message)
        }

        return data
    }

    private func makeMultipartBody(
        boundary: String,
        imageData: Data,
        fileName: String,
        mimeType: String
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        body.append(Data("--\(boundary)\(lineBreak)".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"avatar\"; filename=\"\(fileName)\"\(lineBreak)".utf8))
        body.append(Data("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".utf8))
        body.append(imageData)
        body.append(Data(lineBreak.utf8))
        body.append(Data("--\(boundary)--\(lineBreak)".utf8))

        return body
    }
}

private struct SettingsCurrentUserDTO: Decodable {
    let username: String
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case username
        case userName = "user_name"
        case name
        case avatarURL = "avatar_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        username = try container.decode(String.self, forKeys: [
            "username",
            "user_name",
            "name"
        ])
        avatarURL = try container.decodeIfPresent(String.self, forKeys: [
            "avatar_url",
            "avatarURL"
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
