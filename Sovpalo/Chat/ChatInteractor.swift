import Foundation
import UIKit

protocol ChatBusinessLogic: AnyObject {
    func loadInitial()
    func loadOlder()
    func sendText(_ text: String)
    func sendPhoto(_ image: UIImage)
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
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var consecutiveHandshake400 = 0
    private var wsReconnectDisabled = false
    private var localMessageSeed = -1

    var presenter: ChatPresenterProtocol?
    var worker: ChatWorkerProtocol?

    init(company: Company, currentUserId: Int = 0) {
        self.company = company
        self.currentUserId = currentUserId
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
                }
            } catch {
                await MainActor.run {
                    self.removeLocalMessage(localId: local.id)
                    self.presenter?.presentError(error.localizedDescription)
                }
            }
        }
    }

    func stop() {
        ws?.stop()
        ws = nil
        pollTask?.cancel()
        pollTask = nil
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
                if let idx = messages.firstIndex(where: { $0.id == normalized.id }) {
                    messages[idx] = normalized
                } else {
                    messages.append(normalized)
                    messages.sort(by: { $0.id < $1.id })
                }
                presenter?.presentMessages(messages, hasMore: hasMore, animate: true)
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
                        self.mergeLatest(serverMessages)
                        self.hasMore = page.hasMore
                        self.presenter?.presentMessages(self.messages, hasMore: self.hasMore, animate: false)
                    }
                } catch {
                    // Ignore polling errors; WS may still work.
                    continue
                }
            }
        }
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
