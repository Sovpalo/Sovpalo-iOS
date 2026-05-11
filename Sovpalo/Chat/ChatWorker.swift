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
    func sendMessage(companyId: Int, text: String) async throws -> ChatMessageView
    func sendMessagePhoto(companyId: Int, image: UIImage) async throws -> ChatMessageView
    func connectWebSocket(
        companyId: Int,
        onState: @escaping (ChatWebSocketState) -> Void,
        onEvent: @escaping (ChatRealtimeEvent) -> Void
    ) throws -> ChatWebSocketConnection
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
        let userId = try currentUserIdFromToken()
        return ChatCurrentUserProfile(id: userId, username: dto.username, avatarURL: dto.avatarURL)
    }

    func listMessages(companyId: Int, beforeId: Int?, limit: Int) async throws -> ChatMessagePage {
        var urlString = baseURL + "/companies/\(companyId)/chat/messages?limit=\(limit)"
        if let beforeId, beforeId > 0 {
            urlString += "&before_id=\(beforeId)"
        }
        let request = try makeJSONRequest(path: urlString, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        if data.isEmpty {
            return ChatMessagePage(items: [], hasMore: false)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ChatDateCoding.decodeServerDate)
        let dto = try decoder.decode([ChatMessageDTO].self, from: data)
        let messages = dto.map(mapDTOToView)
        let hasMore = messages.count >= min(max(limit, 1), 100)
        return ChatMessagePage(items: messages, hasMore: hasMore)
    }

    func sendMessage(companyId: Int, text: String) async throws -> ChatMessageView {
        let request = try makeJSONRequest(
            path: baseURL + "/companies/\(companyId)/chat/messages",
            method: "POST"
        )
        var mutableRequest = request
        mutableRequest.httpBody = try JSONEncoder().encode(ChatSendTextPayload(text: text))

        let (data, response) = try await URLSession.shared.data(for: mutableRequest)
        try validate(response: response, data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ChatDateCoding.decodeServerDate)
        let message = try decoder.decode(ChatMessageDTO.self, from: data)
        return mapDTOToView(dto: message)
    }

    func sendMessagePhoto(companyId: Int, image: UIImage) async throws -> ChatMessageView {
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw ChatWorkerError.badServerResponse
        }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = try makeJSONRequest(
            path: baseURL + "/companies/\(companyId)/chat/messages",
            method: "POST"
        )
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = makeMultipartBody(
            boundary: boundary,
            fields: [:],
            fileData: imageData,
            fileName: "chat_photo.jpg",
            mimeType: "image/jpeg"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(ChatDateCoding.decodeServerDate)
        let message = try decoder.decode(ChatMessageDTO.self, from: data)
        return mapDTOToView(dto: message)
    }

    func connectWebSocket(
        companyId: Int,
        onState: @escaping (ChatWebSocketState) -> Void,
        onEvent: @escaping (ChatRealtimeEvent) -> Void
    ) throws -> ChatWebSocketConnection {
        let token = try currentTokenString()
        let wsURLString = websocketBaseURL(from: baseURL) + "/companies/\(companyId)/chat/ws?token=\(token.urlQueryEncoded())"
#if DEBUG
        let previewPrefix = token.prefix(12)
        let previewSuffix = token.suffix(12)
        print("[ChatWS] connect companyId=\(companyId) tokenLen=\(token.count) tokenPreview=\(previewPrefix)…\(previewSuffix)")
        print("[ChatWS] url=\(wsURLString)")
#endif
        guard let url = URL(string: wsURLString) else {
            throw ChatWorkerError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Keep header too; backend supports both header and query param.
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let client = ChatWebSocketClient(request: request, onState: onState, onEvent: onEvent)
        client.start()
        return client
    }

    // no debug probe (WS upgrade handled by URLSessionWebSocketTask)

    private func currentTokenString() throws -> String {
        guard let tokenData = keychain.getData(forKey: "auth.token") else {
            throw ChatWorkerError.tokenNotFound
        }
        guard let token = String(data: tokenData, encoding: .utf8) else {
            throw ChatWorkerError.tokenDecodingFailed
        }
        return token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentUserIdFromToken() throws -> Int {
        let token = try currentTokenString()
        if let userId = JWTUserIDExtractor.userId(fromJWT: token) {
            return userId
        }
        return 0
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
        body.append("Content-Disposition: form-data; name=\"media\"; filename=\"\(fileName)\"\(lineBreak)".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        body.append(fileData)
        body.append(lineBreak.data(using: .utf8)!)
        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return body
    }

    // Mapping helpers live outside the class (shared with WebSocket decoding).
}

private struct ChatSendTextPayload: Encodable {
    let text: String
}

struct ChatRealtimeEvent {
    let type: String
    let companyId: Int
    let message: ChatMessageView?
    let messageId: Int?
}

protocol ChatWebSocketConnection {
    func stop()
}

private final class ChatWebSocketClient: ChatWebSocketConnection {
    private let session: URLSession
    private let task: URLSessionWebSocketTask
    private let onState: (ChatWebSocketState) -> Void
    private let onEvent: (ChatRealtimeEvent) -> Void
    private let decoder: JSONDecoder
    private var isStopped = false
    private var pingTimer: Timer?
    private var emittedTerminalState = false

    init(
        request: URLRequest,
        onState: @escaping (ChatWebSocketState) -> Void,
        onEvent: @escaping (ChatRealtimeEvent) -> Void
    ) {
        let delegate = ChatWebSocketSessionDelegate(authorizationHeader: request.value(forHTTPHeaderField: "Authorization"))
        self.session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        self.task = session.webSocketTask(with: request)
        self.onState = onState
        self.onEvent = onEvent
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom(ChatDateCoding.decodeServerDate)
        delegate.onClose = { [weak self] in
            self?.stop()
        }
        delegate.onOpen = { [weak self] in
            self?.onState(.connected)
        }
#if DEBUG
        delegate.onHTTPComplete = { statusCode, error in
            if let statusCode {
                print("[ChatWS] handshake status=\(statusCode)")
                self.onState(.failedHandshake(statusCode))
                self.emittedTerminalState = true
            }
            if let error {
                print("[ChatWS] task error=\(error)")
            }
        }
#endif
    }

    func start() {
        onState(.connecting)
        task.resume()
        startPing()
        receiveLoop()
    }

    func stop() {
        guard !isStopped else { return }
        isStopped = true
        if !emittedTerminalState {
            onState(.disconnected)
        }
        pingTimer?.invalidate()
        pingTimer = nil
        task.cancel(with: .goingAway, reason: nil)
        session.invalidateAndCancel()
    }

    private func receiveLoop() {
        task.receive { [weak self] result in
            guard let self, !self.isStopped else { return }
            switch result {
            case let .success(message):
                if let data = self.data(from: message),
                   let dto = try? self.decoder.decode(ChatRealtimeEventDTO.self, from: data) {
                    self.onEvent(dto.toDomain())
                }
                self.receiveLoop()
            case .failure:
                self.stop()
            }
        }
    }

    private func startPing() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pingTimer == nil else { return }
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
                guard let self, !self.isStopped else { return }
                self.task.sendPing { error in
                    if error != nil {
                        self.stop()
                    }
                }
            }
        }
    }

    private func data(from message: URLSessionWebSocketTask.Message) -> Data? {
        switch message {
        case let .data(data):
            return data
        case let .string(text):
            return text.data(using: .utf8)
        @unknown default:
            return nil
        }
    }
}

private final class ChatWebSocketSessionDelegate: NSObject, URLSessionWebSocketDelegate, URLSessionTaskDelegate {
    private let authorizationHeader: String?
    var onClose: (() -> Void)?
    var onOpen: (() -> Void)?
#if DEBUG
    var onHTTPComplete: ((_ statusCode: Int?, _ error: Error?) -> Void)?
#endif

    init(authorizationHeader: String?) {
        self.authorizationHeader = authorizationHeader
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        var redirected = request
        if let authorizationHeader {
            redirected.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        }
        completionHandler(redirected)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
#if DEBUG
        let status = (task.response as? HTTPURLResponse)?.statusCode
        onHTTPComplete?(status, error)
#endif
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        onOpen?()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        onClose?()
    }
}

private extension ChatRealtimeEventDTO {
    func toDomain() -> ChatRealtimeEvent {
        ChatRealtimeEvent(
            type: type,
            companyId: companyId,
            message: message.map(mapDTOToView),
            messageId: messageId
        )
    }
}

private func mapDTOToView(dto: ChatMessageDTO) -> ChatMessageView {
    let sentAt = dto.createdAt
    let isOutgoing = false
    let avatarURLString = dto.senderAvatarURL.flatMap { chatAbsoluteURLString($0) }
    if let photoURL = dto.photoURL, let url = chatAbsoluteURL(photoURL) {
        return ChatMessageView(
            id: dto.id,
            senderId: dto.senderID,
            senderName: dto.senderUsername,
            senderAvatarURL: avatarURLString,
            sentAt: sentAt,
            kind: .photoURL(url),
            isOutgoing: isOutgoing
        )
    }
    return ChatMessageView(
        id: dto.id,
        senderId: dto.senderID,
        senderName: dto.senderUsername,
        senderAvatarURL: avatarURLString,
        sentAt: sentAt,
        kind: .text(dto.text ?? ""),
        isOutgoing: isOutgoing
    )
}

private func chatAbsoluteURL(_ raw: String) -> URL? {
    if let url = URL(string: raw), url.scheme != nil {
        return url
    }
    if raw.hasPrefix("/") {
        return URL(string: chatJoinBaseURL(Server.url, path: raw))
    }
    return URL(string: chatJoinBaseURL(Server.url, path: "/" + raw))
}

private func chatAbsoluteURLString(_ raw: String) -> String? {
    chatAbsoluteURL(raw)?.absoluteString
}

private func chatJoinBaseURL(_ base: String, path: String) -> String {
    let trimmedBase = base.hasSuffix("/") ? String(base.dropLast()) : base
    let trimmedPath = path.hasPrefix("/") ? path : ("/" + path)
    return trimmedBase + trimmedPath
}

private func websocketBaseURL(from httpBase: String) -> String {
    if httpBase.hasPrefix("https://") {
        return "wss://" + httpBase.dropFirst("https://".count)
    }
    if httpBase.hasPrefix("http://") {
        return "ws://" + httpBase.dropFirst("http://".count)
    }
    return httpBase
}
