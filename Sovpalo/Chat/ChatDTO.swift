import Foundation

enum ChatDateCoding {
    static func decodeServerDate(decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) {
            return date
        }

        let isoNoFrac = ISO8601DateFormatter()
        isoNoFrac.formatOptions = [.withInternetDateTime]
        if let date = isoNoFrac.date(from: value) {
            return date
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
    }
}

struct ChatMessageDTO: Decodable {
    let id: Int
    let text: String?
    let attachment: ChatAttachmentDTO?
    let senderID: Int
    let senderUsername: String
    let senderAvatarURL: String?
    let createdAt: Date
    let attachments: [ChatAttachmentDTO]

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case createdAt = "created_at"
        case senderID = "sender_id"
        case senderUsername = "sender_username"
        case senderAvatarURL = "sender_avatar_url"
        case attachments
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        senderID = try c.decodeIfPresent(Int.self, forKey: .senderID) ?? 0
        senderUsername = try c.decodeIfPresent(String.self, forKey: .senderUsername) ?? "User"
        senderAvatarURL = try c.decodeIfPresent(String.self, forKey: .senderAvatarURL)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        attachments = try c.decodeIfPresent([ChatAttachmentDTO].self, forKey: .attachments) ?? []

        attachment = attachments.first
    }
}

struct ChatAttachmentDTO: Decodable {
    let fileURL: String
    let mediaType: String

    enum CodingKeys: String, CodingKey {
        case fileURL = "file_url"
        case mediaType = "media_type"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fileURL = try c.decode(String.self, forKey: .fileURL)
        mediaType = try c.decodeIfPresent(String.self, forKey: .mediaType) ?? "photo"
    }
}

struct ChatCurrentUserProfileDTO: Decodable {
    let username: String
    let avatarURL: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ChatAnyCodingKey.self)
        username = try c.decodeIfPresent(String.self, forKeys: ["username", "name", "user_name"]) ?? "Вы"
        avatarURL = try c.decodeIfPresent(String.self, forKeys: ["avatar_url", "photo_url"])
    }
}

enum JWTUserIDExtractor {
    static func userId(fromJWT token: String) -> Int? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payload = String(parts[1])
        guard let data = Data(base64URLEncoded: payload) else { return nil }
        guard
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let userId = json["user_id"] as? NSNumber
        else {
            return nil
        }
        return userId.intValue
    }
}

extension Data {
    init?(base64URLEncoded input: String) {
        var base64 = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = base64.count % 4
        if pad != 0 {
            base64 += String(repeating: "=", count: 4 - pad)
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        self = data
    }
}

extension String {
    func urlQueryEncoded() -> String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

struct ChatRealtimeEventDTO: Decodable {
    let type: String
    let companyId: Int
    let message: ChatMessageDTO?
    let messageId: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case companyId = "company_id"
        case message
        case messageId = "message_id"
    }
}

struct ChatAnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
    init(_ string: String) { self.stringValue = string; self.intValue = nil }
}

extension KeyedDecodingContainer where K == ChatAnyCodingKey {
    func decode<T: Decodable>(_ type: T.Type, forKeys keys: [String]) throws -> T {
        for key in keys {
            if let value = try decodeIfPresent(type, forKey: ChatAnyCodingKey(key)) {
                return value
            }
        }
        throw DecodingError.keyNotFound(
            ChatAnyCodingKey(keys[0]),
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing keys: \(keys)")
        )
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKeys keys: [String]) throws -> T? {
        for key in keys {
            if let value = try decodeIfPresent(type, forKey: ChatAnyCodingKey(key)) {
                return value
            }
        }
        return nil
    }
}
