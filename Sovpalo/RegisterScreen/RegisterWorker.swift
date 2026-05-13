//
//  RegisterWorker.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 31.01.2026.
//

import Foundation

protocol RegisterWorkerProtocol {
    /// Запускает регистрацию и отправку кода подтверждения (POST /auth/sign-up)
    /// - Parameters:
    ///   - email: Электронная почта
    ///   - username: Имя пользователя
    ///   - password: Пароль
    func register(email: String, username: String, password: String) async throws
    func telegramAuthURL() async throws -> URL
    func signInTelegram(payload: TelegramSignInPayload) async throws -> String

    /// Проверяет, соответствует ли пароль требованиям
    func validatePassword(_ password: String) -> RegisterPasswordValidation
}

// MARK: - Models

private struct RegisterRequestBody: Codable {
    let email: String
    let username: String
    let password: String
}

private struct RegisterResponseBody: Decodable {
    let message: String?
    let expiresInSec: Int?
}

private struct TelegramSignInRequestBody: Encodable {
    let initData: String?
    let id: Int64?
    let firstName: String?
    let lastName: String?
    let username: String?
    let photoURL: String?
    let authDate: Int64?
    let hash: String?

    enum CodingKeys: String, CodingKey {
        case initData = "init_data"
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case photoURL = "photo_url"
        case authDate = "auth_date"
        case hash
    }
}

private struct TelegramSignInResponseBody: Decodable {
    let token: String
}

private struct TelegramRegisterResponseBody: Decodable {
    let botURL: String?
    let miniAppURL: String?
    let webappURL: String?
    let deepLink: String?

    enum CodingKeys: String, CodingKey {
        case botURL = "bot_url"
        case miniAppURL = "mini_app_url"
        case webappURL = "webapp_url"
        case deepLink = "deep_link"
    }
}

// MARK: - Errors

enum RegisterError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case http(statusCode: Int)
    case decodingFailed
    case invalidPassword
    case telegramAuthUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .http(let code): return "HTTP error: \(code)"
        case .decodingFailed: return "Failed to decode server response"
        case .invalidPassword: return "Пароль не соответствует требованиям"
        case .telegramAuthUnavailable:
            return "Telegram-вход пока не настроен на сервере. Нужен mini_app_url или bot_url."
        }
    }
}

struct RegisterPasswordValidation {
    let hasUppercaseLetter: Bool
    let hasLowercaseLetter: Bool
    let hasThreeDigits: Bool
    let hasSpecialCharacter: Bool
    let hasMinimumLength: Bool
    let isEmpty: Bool

    var isValid: Bool {
        hasUppercaseLetter &&
        hasLowercaseLetter &&
        hasThreeDigits &&
        hasSpecialCharacter &&
        hasMinimumLength
    }
}

struct TelegramSignInPayload {
    let initData: String?
    let id: Int64?
    let firstName: String?
    let lastName: String?
    let username: String?
    let photoURL: String?
    let authDate: Int64?
    let hash: String?

    var isValid: Bool {
        let hasInitData = !(initData?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasLoginWidgetFields = id != nil && authDate != nil && !(hash?.isEmpty ?? true)
        return hasInitData || hasLoginWidgetFields
    }
}

final class RegisterWorker: RegisterWorkerProtocol {
    // MARK: - Dependencies
    private let network: any NetworkServicing
    private let keychain: KeychainLogic
    private let fallbackTelegramAuthURL = URL(string: "https://t.me/sovpalo_auth_bot?startapp=auth")!

    init(
        baseURL: URL? = URL(string: Server.url),
        urlSession: URLSession = .shared,
        keychain: KeychainLogic = KeychainService(),
        network: (any NetworkServicing)? = nil
    ) {
        self.keychain = keychain
        self.network = network ?? NetworkService(
            baseURL: baseURL ?? URL(string: Server.url)!,
            session: urlSession,
            keychain: keychain
        )
    }

    // MARK: - API

    func register(email: String, username: String, password: String) async throws {
        let data = try await network.data(
            path: "auth/sign-up",
            method: .post,
            authorized: false,
            body: try JSONEncoder().encode(
                RegisterRequestBody(email: email, username: username, password: password)
            ),
            contentType: "application/json",
            headers: [:]
        )

        if !data.isEmpty {
            do {
                _ = try JSONDecoder().decode(RegisterResponseBody.self, from: data)
            } catch {
                throw RegisterError.decodingFailed
            }
        }
    }

    func telegramAuthURL() async throws -> URL {
        do {
            if let url = try await fetchTelegramRegisterURL() {
                return url
            }
        } catch {
            return fallbackTelegramAuthURL
        }

        return fallbackTelegramAuthURL
    }

    func signInTelegram(payload: TelegramSignInPayload) async throws -> String {
        guard payload.isValid else { throw RegisterError.invalidResponse }

        let decoded: TelegramSignInResponseBody
        do {
            decoded = try await network.decoded(
                path: "auth/telegram/sign-in",
                method: .post,
                authorized: false,
                body: makeTelegramSignInRequestBody(from: payload),
                encoder: JSONEncoder(),
                decoder: JSONDecoder(),
                headers: [:]
            )
        } catch is DecodingError {
            throw RegisterError.decodingFailed
        }

        keychain.setData(Data(decoded.token.utf8), forKey: "auth.token")
        if let userID = decodeUserIDFromJWT(decoded.token) {
            keychain.setData(Data("\(userID)".utf8), forKey: "auth.userId")
        }
        return decoded.token
    }

    func validatePassword(_ password: String) -> RegisterPasswordValidation {
        let digitsCount = password.filter { $0 >= "1" && $0 <= "9" }.count
        let specialCharacters = CharacterSet.punctuationCharacters.union(.symbols)

        return RegisterPasswordValidation(
            hasUppercaseLetter: password.rangeOfCharacter(from: .uppercaseLetters) != nil,
            hasLowercaseLetter: password.rangeOfCharacter(from: .lowercaseLetters) != nil,
            hasThreeDigits: digitsCount >= 3,
            hasSpecialCharacter: password.rangeOfCharacter(from: specialCharacters) != nil,
            hasMinimumLength: password.count >= 8,
            isEmpty: password.isEmpty
        )
    }

    private func makeTelegramSignInRequestBody(
        from payload: TelegramSignInPayload
    ) -> TelegramSignInRequestBody {
        TelegramSignInRequestBody(
            initData: payload.initData,
            id: payload.id,
            firstName: payload.firstName,
            lastName: payload.lastName,
            username: payload.username,
            photoURL: payload.photoURL,
            authDate: payload.authDate,
            hash: payload.hash
        )
    }

    private func fetchTelegramRegisterURL() async throws -> URL? {
        let decoded: TelegramRegisterResponseBody
        do {
            decoded = try await network.decoded(
                path: "auth/telegram/register",
                method: .get,
                authorized: false,
                decoder: JSONDecoder(),
                headers: [:]
            )
        } catch NetworkServiceError.badStatus(code: 404, message: _) {
            return nil
        } catch NetworkServiceError.emptyResponse {
            return nil
        }

        return preferredTelegramURL(from: decoded)
    }

    private func preferredTelegramURL(from response: TelegramRegisterResponseBody) -> URL? {
        let candidates = [
            response.miniAppURL,
            response.botURL
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap(URL.init(string:))
            .first
    }

    private func decodeUserIDFromJWT(_ token: String) -> Int? {
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }

        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 += "="
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let userID = json["user_id"] as? Int else { return nil }
        return userID
    }
}
