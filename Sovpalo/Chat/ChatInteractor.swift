import Foundation
import UIKit
import AVFoundation

protocol ChatBusinessLogic: AnyObject {
    func loadInitial()
    func loadOlder()
    func sendText(_ text: String)
    func sendPhoto(_ image: UIImage)
    func sendVideo(_ videoURL: URL)
    func deleteMessage(id: Int)
    func editMessageRequested(id: Int)
    func stop()
}

final class ChatInteractor: ChatBusinessLogic {
    private let company: Company
    private let currentUserId: Int
    private var messages: [ChatMessageView] = []
    private var hasMore = true
    private var isLoading = false
    private var currentProfile = ChatCurrentUserProfile(id: 0, username: "Вы", avatarURL: nil)
    private var ws: ChatWebSocketConnection?
    private var pollTask: Task<Void, Never>?
    private var profileRefreshTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var consecutiveHandshake400 = 0
    private var wsReconnectDisabled = false
    private var localMessageSeed = -1
    private var lastMembersById: [Int: String?] = [:]
    private let membersWorker: CompanyMembersWorkerProtocol
    private let soundPlayer: ChatMessageSoundPlaying

    var presenter: ChatPresenterProtocol?
    var worker: ChatWorkerProtocol?

    init(
        company: Company,
        currentUserId: Int = 0,
        membersWorker: CompanyMembersWorkerProtocol = CompanyMembersWorker(),
        soundPlayer: ChatMessageSoundPlaying = ChatMessageSoundPlayer()
    ) {
        self.company = company
        self.currentUserId = currentUserId
        self.membersWorker = membersWorker
        self.soundPlayer = soundPlayer

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(currentUserAvatarDidChange),
            name: .currentUserAvatarDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func loadInitial() {
        guard let worker, !isLoading else { return }
        isLoading = true
        presenter?.presentLoading(true)
        presenter?.presentConnectionState(.connecting)

        Task {
            do {
                if let profile = try? await worker.fetchCurrentProfile() {
                    currentProfile = profile
                }
                if ws == nil {
                    ws = try worker.connectWebSocket(
                        companyId: company.id,
                        onState: { [weak self] state in
                            self?.handleWebSocketState(state)
                        },
                        onEvent: { [weak self] event in
                            self?.handleRealtimeEvent(event)
                        }
                    )
                }
                let page = try await worker.listMessages(companyId: company.id, beforeId: nil, limit: 20)
                messages = page.items
                    .sorted(by: { $0.id < $1.id })
                    .map { normalizeOutgoing($0) }
                hasMore = page.hasMore
                await MainActor.run {
                    self.presenter?.presentLoading(false)
                    self.presenter?.presentMessages(self.messages, hasMore: self.hasMore, animate: false)
                    self.isLoading = false
                }
                startPollingIfNeeded()
                startProfileRefreshIfNeeded()
            } catch {
                await MainActor.run {
                    self.presenter?.presentLoading(false)
                    self.presenter?.presentError(error.localizedDescription)
                    self.isLoading = false
                }
            }
        }
    }

    func loadOlder() {
        guard let worker, !isLoading, hasMore else { return }
        guard let oldestID = messages.first?.id, oldestID > 0 else { return }
        isLoading = true
        presenter?.presentPaging(true)

        Task {
            do {
                let page = try await worker.listMessages(companyId: company.id, beforeId: oldestID, limit: 20)
                let older = page.items
                    .sorted(by: { $0.id < $1.id })
                    .map { self.normalizeOutgoing($0) }
                messages.insert(contentsOf: older, at: 0)
                hasMore = page.hasMore
                await MainActor.run {
                    self.presenter?.presentPaging(false)
                    self.presenter?.presentMessages(self.messages, hasMore: self.hasMore, animate: false)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.presenter?.presentPaging(false)
                    self.presenter?.presentError(error.localizedDescription)
                    self.isLoading = false
                }
            }
        }
    }

    func sendText(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let local = makeLocalMessage(kind: .text(clean))
        messages.append(local)
        presenter?.presentMessages(messages, hasMore: hasMore, animate: true)

        Task {
            do {
                let created = try await worker?.sendMessage(companyId: company.id, text: clean)
                guard let created else { return }
                await MainActor.run {
                    self.replaceLocalMessage(localId: local.id, with: self.normalizeOutgoing(created))
                    self.soundPlayer.playOutgoingMessageSound()
                }
            } catch {
                await MainActor.run {
                    self.removeLocalMessage(localId: local.id)
                    self.presenter?.presentError(error.localizedDescription)
                }
            }
        }
    }

    func sendPhoto(_ image: UIImage) {
        let local = makeLocalMessage(kind: .photo(image))
        messages.append(local)
        presenter?.presentMessages(messages, hasMore: hasMore, animate: true)

        Task {
            do {
                let created = try await worker?.sendMessagePhoto(companyId: company.id, image: image)
                guard let created else { return }
                await MainActor.run {
                    self.replaceLocalMessage(localId: local.id, with: self.normalizeOutgoing(created))
                    self.soundPlayer.playOutgoingMessageSound()
                }
            } catch {
                await MainActor.run {
                    self.removeLocalMessage(localId: local.id)
                    self.presenter?.presentError(error.localizedDescription)
                }
            }
        }
    }

    func sendVideo(_ videoURL: URL) {
        let local = makeLocalMessage(kind: .videoURL(videoURL))
        messages.append(local)
        presenter?.presentMessages(messages, hasMore: hasMore, animate: true)

        Task {
            do {
                // Normalize/transcode to a backend-friendly container (prefer MP4, fallback MOV)
                let normalizedURL = try await normalizeVideoForBackend(videoURL)
                let created = try await worker?.sendMessageVideo(companyId: company.id, videoURL: normalizedURL)
                guard let created else { return }
                await MainActor.run {
                    self.replaceLocalMessage(localId: local.id, with: self.normalizeOutgoing(created))
                    self.soundPlayer.playOutgoingMessageSound()
                }
            } catch {
                await MainActor.run {
                    self.removeLocalMessage(localId: local.id)
                    self.presenter?.presentError(error.localizedDescription)
                }
            }
        }
    }

    // Normalize/transcode video to a backend-supported container. Prefer MP4 (H.264/AAC), fallback to MOV.
    private func normalizeVideoForBackend(_ url: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)

        // Prefer exporting to MP4 when supported to avoid HEVC in MOV containers.
        if let mp4Session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality),
           mp4Session.supportedFileTypes.contains(.mp4) {
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("chat-transcoded-\(UUID().uuidString)")
                .appendingPathExtension("mp4")
            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            mp4Session.outputURL = destination
            mp4Session.outputFileType = .mp4
            mp4Session.shouldOptimizeForNetworkUse = true
            try await awaitExport(mp4Session)
            return destination
        }

        // Fallback: export to MOV if MP4 is not supported by the asset.
        if let movSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality),
           movSession.supportedFileTypes.contains(.mov) {
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("chat-transcoded-\(UUID().uuidString)")
                .appendingPathExtension("mov")
            if FileManager.default.fileExists(atPath: destination.path) {
                try? FileManager.default.removeItem(at: destination)
            }
            movSession.outputURL = destination
            movSession.outputFileType = .mov
            movSession.shouldOptimizeForNetworkUse = true
            try await awaitExport(movSession)
            return destination
        }

        // If we cannot export at all, return the original URL as a last resort.
        // However, most HEVC/unsupported cases should be handled by the MP4 path above.
        return url
    }

    private func awaitExport(_ session: AVAssetExportSession) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: session.error ?? NSError(
                        domain: "ChatInteractor",
                        code: -1002,
                        userInfo: [NSLocalizedDescriptionKey: "Не удалось подготовить видео к отправке."]
                    ))
                default:
                    if let error = session.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "ChatInteractor",
                            code: -1003,
                            userInfo: [NSLocalizedDescriptionKey: "Не удалось подготовить видео к отправке."]
                        ))
                    }
                }
            }
        }
    }

    func deleteMessage(id: Int) {
        guard id > 0 else { return }
        guard let worker else { return }
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }

        let removed = messages.remove(at: index)
        presenter?.presentMessages(messages, hasMore: hasMore, animate: false)

        Task {
            do {
                try await worker.deleteMessage(companyId: company.id, messageId: id)
            } catch {
                await MainActor.run {
                    // Rollback on failure
                    self.messages.insert(removed, at: min(index, self.messages.count))
                    self.presenter?.presentMessages(self.messages, hasMore: self.hasMore, animate: false)
                    self.presenter?.presentError(error.localizedDescription)
                }
            }
        }
    }

    func editMessageRequested(id: Int) {
        presenter?.presentError("Редактирование сообщений пока не поддерживается сервером.")
    }

    func stop() {
        ws?.stop()
        ws = nil
        pollTask?.cancel()
        pollTask = nil
        profileRefreshTask?.cancel()
        profileRefreshTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempt = 0
        consecutiveHandshake400 = 0
        wsReconnectDisabled = false
        presenter?.presentConnectionState(.disconnected)
    }

    private func makeLocalMessage(kind: ChatMessageKind) -> ChatMessageView {
        localMessageSeed -= 1
        return ChatMessageView(
            id: localMessageSeed,
            senderId: currentProfile.id == 0 ? currentUserId : currentProfile.id,
            senderName: currentProfile.username,
            senderAvatarURL: currentProfile.avatarURL,
            sentAt: Date(),
            kind: kind,
            isOutgoing: true
        )
    }

    private func normalizeOutgoing(_ message: ChatMessageView) -> ChatMessageView {
        let isOutgoing = message.senderId != 0 && message.senderId == currentProfile.id
        if !isOutgoing {
            return ChatMessageView(
                id: message.id,
                senderId: message.senderId,
                senderName: message.senderName,
                senderAvatarURL: message.senderAvatarURL,
                sentAt: message.sentAt,
                kind: message.kind,
                isOutgoing: false
            )
        }
        return ChatMessageView(
            id: message.id,
            senderId: currentProfile.id,
            senderName: currentProfile.username,
            senderAvatarURL: currentProfile.avatarURL ?? message.senderAvatarURL,
            sentAt: message.sentAt,
            kind: message.kind,
            isOutgoing: true
        )
    }

    private func replaceLocalMessage(localId: Int, with server: ChatMessageView) {
        if let idx = messages.firstIndex(where: { $0.id == localId }) {
            messages[idx] = server
            // If the same server message already arrived via WebSocket, dedupe.
            for i in messages.indices.reversed() where i != idx && messages[i].id == server.id {
                messages.remove(at: i)
            }
            messages.sort(by: { $0.id < $1.id })
            presenter?.presentMessages(messages, hasMore: hasMore, animate: true)
            return
        }
        if !messages.contains(where: { $0.id == server.id }) {
            messages.append(server)
            presenter?.presentMessages(messages, hasMore: hasMore, animate: true)
        }
    }

    private func removeLocalMessage(localId: Int) {
        if let idx = messages.firstIndex(where: { $0.id == localId }) {
            messages.remove(at: idx)
            presenter?.presentMessages(messages, hasMore: hasMore, animate: true)
        }
    }

    private func handleRealtimeEvent(_ event: ChatRealtimeEvent) {
        guard event.companyId == company.id else { return }
        switch event.type {
        case "message_created":
            guard let message = event.message else { return }
            Task { @MainActor in
                let normalized = normalizeOutgoing(message)
                let isNewMessage = !messages.contains(where: { $0.id == normalized.id })
                if let idx = messages.firstIndex(where: { $0.id == normalized.id }) {
                    messages[idx] = normalized
                } else {
                    messages.append(normalized)
                    messages.sort(by: { $0.id < $1.id })
                }
                presenter?.presentMessages(messages, hasMore: hasMore, animate: true)
                playIncomingMessageSoundIfNeeded(for: normalized, isNewMessage: isNewMessage)
            }
        case "message_deleted":
            guard let id = event.messageId else { return }
            Task { @MainActor in
                messages.removeAll(where: { $0.id == id })
                presenter?.presentMessages(messages, hasMore: hasMore, animate: false)
            }
        default:
            return
        }
    }

    private func startPollingIfNeeded() {
        guard pollTask == nil else { return }
        guard let worker else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if Task.isCancelled { break }
                do {
                    let page = try await worker.listMessages(companyId: company.id, beforeId: nil, limit: 50)
                    let serverMessages = page.items.map { self.normalizeOutgoing($0) }
                    await MainActor.run {
                        let newestExistingId = self.messages.map(\.id).filter { $0 > 0 }.max() ?? 0
                        let hasNewIncomingMessage = serverMessages.contains {
                            $0.id > newestExistingId && !$0.isOutgoing
                        }
                        self.mergeLatest(serverMessages)
                        self.hasMore = page.hasMore
                        self.presenter?.presentMessages(self.messages, hasMore: self.hasMore, animate: false)
                        if hasNewIncomingMessage {
                            self.soundPlayer.playIncomingMessageSound()
                        }
                    }
                    await self.refreshAvatarsFromMembers()
                } catch {
                    // Ignore polling errors; WS may still work.
                    continue
                }
            }
        }
    }

    private func refreshAvatarsFromMembers() async {
        // Use the same 15s polling cadence: refresh member avatars and update visible messages if needed.
        guard let members = try? await membersWorker.fetchMembers(companyID: company.id) else { return }
        var map: [Int: String?] = [:]
        map.reserveCapacity(members.count)
        for member in members {
            map[member.userID] = member.avatarURL
        }
        if map.keys.count == 0 { return }

        // Avoid UI churn if nothing changed.
        if membersFingerprint(map) == membersFingerprint(lastMembersById) {
            return
        }
        lastMembersById = map

        await MainActor.run {
            var changed = false
            for i in messages.indices {
                let msg = messages[i]
                // We already force outgoing avatar from currentProfile; only update incoming.
                guard !msg.isOutgoing else { continue }
                guard map.keys.contains(msg.senderId) else { continue }
                let absolute = map[msg.senderId].flatMap { $0 }.flatMap(absoluteURLString)
                if msg.senderAvatarURL != absolute {
                    messages[i] = ChatMessageView(
                        id: msg.id,
                        senderId: msg.senderId,
                        senderName: msg.senderName,
                        senderAvatarURL: absolute,
                        sentAt: msg.sentAt,
                        kind: msg.kind,
                        isOutgoing: msg.isOutgoing
                    )
                    changed = true
                }
            }
            if changed {
                presenter?.presentMessages(messages, hasMore: hasMore, animate: false)
            }
        }
    }

    private func membersFingerprint(_ map: [Int: String?]) -> String {
        map
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value ?? "nil")" }
            .joined(separator: "|")
    }

    private func absoluteURLString(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url.absoluteString
        }
        let base = Server.url.hasSuffix("/") ? String(Server.url.dropLast()) : Server.url
        let path = trimmed.hasPrefix("/") ? trimmed : ("/" + trimmed)
        return base + path
    }

    private func startProfileRefreshIfNeeded() {
        guard profileRefreshTask == nil else { return }
        guard let worker else { return }
        profileRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60s
                if Task.isCancelled { break }
                if let profile = try? await worker.fetchCurrentProfile() {
                    await MainActor.run {
                        self.currentProfile = profile
                        self.refreshOutgoingAvatarURL()
                    }
                }
            }
        }
    }

    @MainActor
    private func refreshOutgoingAvatarURL(force: Bool = false) {
        var changed = false
        for i in messages.indices {
            guard messages[i].isOutgoing else { continue }
            if force || messages[i].senderAvatarURL != currentProfile.avatarURL {
                messages[i] = ChatMessageView(
                    id: messages[i].id,
                    senderId: messages[i].senderId,
                    senderName: messages[i].senderName,
                    senderAvatarURL: currentProfile.avatarURL,
                    sentAt: messages[i].sentAt,
                    kind: messages[i].kind,
                    isOutgoing: messages[i].isOutgoing
                )
                changed = true
            }
        }
        if changed {
            presenter?.presentMessages(messages, hasMore: hasMore, animate: false)
        }
    }

    @objc private func currentUserAvatarDidChange(_ notification: Notification) {
        let avatarURL = (notification.userInfo?["avatarURL"] as? String).flatMap(absoluteURLString)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.currentProfile = ChatCurrentUserProfile(
                id: self.currentProfile.id,
                username: self.currentProfile.username,
                avatarURL: avatarURL
            )
            self.refreshOutgoingAvatarURL(force: true)
        }
    }

    @MainActor
    private func playIncomingMessageSoundIfNeeded(for message: ChatMessageView, isNewMessage: Bool) {
        guard isNewMessage, !message.isOutgoing else { return }
        soundPlayer.playIncomingMessageSound()
    }

    private func handleWebSocketState(_ state: ChatWebSocketState) {
        presenter?.presentConnectionState(state)
        if state == .connected {
            reconnectAttempt = 0
            reconnectTask?.cancel()
            reconnectTask = nil
            consecutiveHandshake400 = 0
            wsReconnectDisabled = false
            return
        }
        if case let .failedHandshake(code) = state {
            if code == 400 {
                consecutiveHandshake400 += 1
                if consecutiveHandshake400 >= 3 {
                    // Temporary safety: stop hammering the server if Upgrade is broken.
                    wsReconnectDisabled = true
                    reconnectTask?.cancel()
                    reconnectTask = nil
                    ws?.stop()
                    ws = nil
                    presenter?.presentConnectionState(.disconnected)
                    return
                }
            } else {
                consecutiveHandshake400 = 0
            }
            scheduleReconnect()
            return
        }
        if state == .disconnected {
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        guard reconnectTask == nil else { return }
        guard let worker else { return }
        guard !wsReconnectDisabled else { return }

        reconnectTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let delay = min(30.0, pow(2.0, Double(reconnectAttempt)))
                reconnectAttempt += 1
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { break }

                do {
                    await MainActor.run {
                        self.presenter?.presentConnectionState(.connecting)
                    }
                    self.ws?.stop()
                    self.ws = try worker.connectWebSocket(
                        companyId: self.company.id,
                        onState: { [weak self] state in
                            self?.handleWebSocketState(state)
                        },
                        onEvent: { [weak self] event in
                            self?.handleRealtimeEvent(event)
                        }
                    )
                } catch {
                    continue
                }
            }
        }
    }

    @MainActor
    private func mergeLatest(_ serverMessages: [ChatMessageView]) {
        // Keep local (negative id) messages that are still pending.
        let pendingLocal = messages.filter { $0.id < 0 }
        var byId: [Int: ChatMessageView] = [:]
        for msg in serverMessages {
            byId[msg.id] = msg
        }
        let merged = byId.values.sorted(by: { $0.id < $1.id }) + pendingLocal
        messages = merged.sorted(by: { $0.id < $1.id })
    }
}

