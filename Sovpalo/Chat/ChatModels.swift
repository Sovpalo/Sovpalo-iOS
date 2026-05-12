import Foundation
import UIKit
import MessageKit

enum ChatMessageKind {
    case text(String)
    case photo(UIImage)
    case photoURL(URL)
    case videoURL(URL)
}

struct ChatMessageView {
    let id: Int
    let senderId: Int
    let senderName: String
    let senderAvatarURL: String?
    let sentAt: Date
    let kind: ChatMessageKind
    let isOutgoing: Bool
}

struct ChatMessagePage {
    let items: [ChatMessageView]
    let hasMore: Bool
}

struct ChatCurrentUserProfile {
    let id: Int
    let username: String
    let avatarURL: String?
}

struct ChatMessageItem: MessageType {
    let messageId: String
    let sender: SenderType
    let sentDate: Date
    let kind: MessageKind
}

struct ChatSender: SenderType {
    let senderId: String
    let displayName: String
}

struct ChatImageMediaItem: MediaItem {
    let url: URL?
    let image: UIImage?
    let placeholderImage: UIImage
    let size: CGSize
}

enum ChatWebSocketState: Equatable {
    case connecting
    case connected
    case disconnected
    case failedHandshake(Int)
}
