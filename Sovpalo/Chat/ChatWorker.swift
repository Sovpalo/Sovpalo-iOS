import Foundation
import UIKit

enum ChatWorkerError: LocalizedError {
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
            return "Ошибка чата (\(code)): \(message)"
        }
    }
}

protocol ChatWorkerProtocol {
    func fetchCurrentProfile() async throws -> ChatCurrentUserProfile
    func listMessages(companyId: Int, beforeId: Int?, limit: Int) async throws -> ChatMessagePage
    func sendMessage(companyId: Int, text: String) async throws
    func sendMessagePhoto(companyId: Int, image: UIImage) async throws
}

final class ChatWorker: ChatWorkerProtocol {
    private let keychain: KeychainLogic
    private let baseURL = Server.url

    init(keychain: KeychainLogic = KeychainService()) {
        self.keychain = keychain
    }

    func fetchCurrentProfile() async throws -> ChatCurrentUserProfile {
        let request = try makeJSONRequest(path: baseURL + "/auth/me", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        let decoder = JSONDecoder()
        let dto = try decoder.decode(ChatCurrentUserProfileDTO.self, from: data)
        return ChatCurrentUserProfile(id: dto.id, username: dto.username, avatarURL: dto.avatarURL)
    }

    func listMessages(companyId: Int, beforeId: Int?, limit: Int) async throws -> ChatMessagePage {
        var urlString = baseURL + "/companies/\(companyId)/chat/messages?limit=\(limit)"
        if let beforeId {
            urlString += "&before_id=\(beforeId)"
        }
        let request = try makeJSONRequest(path: urlString, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        if data.isEmpty {
            return ChatMessagePage(items: [], hasMore: false)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(ChatListResponseDTO.self, from: data)
        let messages = dto.items.map(mapDTOToView)
        return ChatMessagePage(items: messages, hasMore: dto.hasMore)
    }

    func sendMessage(companyId: Int, text: String) async throws {
        let request = try makeJSONRequest(
            path: baseURL + "/companies/\(companyId)/chat/messages",
            method: "POST"
        )
        var mutableRequest = request
        mutableRequest.httpBody = try JSONEncoder().encode(ChatSendTextPayload(text: text))

        let (data, response) = try await URLSession.shared.data(for: mutableRequest)
        try validate(response: response, data: data)
    }

    func sendMessagePhoto(companyId: Int, image: UIImage) async throws {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else { return }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = try makeJSONRequest(
            path: baseURL + "/companies/\(companyId)/chat/messages",
            method: "POST"
        )
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = makeMultipartBody(
            boundary: boundary,
            fields: ["text": "Фото"],
            fileData: imageData,
            fileName: "chat_photo.jpg",
            mimeType: "image/jpeg"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    private func makeJSONRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: path) else {
            throw ChatWorkerError.invalidURL
        }

        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw ChatWorkerError.tokenNotFound
        }
        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw ChatWorkerError.tokenDecodingFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ChatWorkerError.badServerResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw ChatWorkerError.badStatus(code: http.statusCode, message: message)
        }
    }

    private func makeMultipartBody(
        boundary: String,
        fields: [String: String],
        fileData: Data,
        fileName: String,
        mimeType: String
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        for (key, value) in fields {
            body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(lineBreak)\(lineBreak)".data(using: .utf8)!)
            body.append("\(value)\(lineBreak)".data(using: .utf8)!)
        }
        body.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"\(fileName)\"\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append(fileData)
        body.append(lineBreak.data(using: .utf8)!)
        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return body
    }

    private func mapDTOToView(dto: ChatMessageDTO) -> ChatMessageView {
        let sentAt = ISO8601DateFormatter().date(from: dto.createdAt) ?? Date()
        let isOutgoing = dto.isMine
        if let photoURL = dto.photoURL {
            return ChatMessageView(
                id: dto.id,
                senderId: dto.authorID,
                senderName: dto.authorName,
                senderAvatarURL: dto.authorAvatarURL,
                sentAt: sentAt,
                kind: .text(photoURL),
                isOutgoing: isOutgoing
            )
        }
        return ChatMessageView(
            id: dto.id,
            senderId: dto.authorID,
            senderName: dto.authorName,
            senderAvatarURL: dto.authorAvatarURL,
            sentAt: sentAt,
            kind: .text(dto.text ?? ""),
            isOutgoing: isOutgoing
        )
    }
}

private struct ChatListResponseDTO: Decodable {
    let items: [ChatMessageDTO]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case hasMore = "has_more"
    }
}

private struct ChatMessageDTO: Decodable {
    let id: Int
    let text: String?
    let photoURL: String?
    let authorID: Int
    let authorName: String
    let authorAvatarURL: String?
    let createdAt: String
    let isMine: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        id = try c.decode(Int.self, forKeys: ["id"])
        text = try c.decodeIfPresent(String.self, forKeys: ["text", "message", "content"])
        photoURL = try c.decodeIfPresent(String.self, forKeys: ["photo_url", "image_url"])
        authorID = try c.decodeIfPresent(Int.self, forKeys: ["author_id", "user_id", "sender_id"]) ?? 0
        authorName = try c.decodeIfPresent(String.self, forKeys: ["author_name", "username", "sender_name"]) ?? "User"
        authorAvatarURL = try c.decodeIfPresent(String.self, forKeys: ["author_avatar_url", "avatar_url", "sender_avatar_url"])
        createdAt = try c.decodeIfPresent(String.self, forKeys: ["created_at", "date"]) ?? ISO8601DateFormatter().string(from: Date())
        isMine = try c.decodeIfPresent(Bool.self, forKeys: ["is_mine", "mine", "isMine"]) ?? false
    }
}

private struct ChatCurrentUserProfileDTO: Decodable {
    let id: Int
    let username: String
    let avatarURL: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        id = try c.decodeIfPresent(Int.self, forKeys: ["id", "user_id"]) ?? 0
        username = try c.decodeIfPresent(String.self, forKeys: ["username", "name", "user_name"]) ?? "Вы"
        avatarURL = try c.decodeIfPresent(String.self, forKeys: ["avatar_url", "photo_url"])
    }
}

private struct ChatSendTextPayload: Encodable {
    let text: String
}

private struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    init(_ string: String) { self.stringValue = string; self.intValue = nil }
}

private extension KeyedDecodingContainer where K == AnyCodingKey {
    func decode<T: Decodable>(_ type: T.Type, forKeys keys: [String]) throws -> T {
        for key in keys {
            if let value = try decodeIfPresent(type, forKey: AnyCodingKey(key)) {
                return value
            }
        }
        throw DecodingError.keyNotFound(
            AnyCodingKey(keys[0]),
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing keys: \(keys)")
        )
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKeys keys: [String]) throws -> T? {
        for key in keys {
            if let value = try decodeIfPresent(type, forKey: AnyCodingKey(key)) {
                return value
            }
        }
        return nil
    }
}
