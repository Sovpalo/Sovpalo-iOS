import Foundation
import UIKit

protocol ChatBusinessLogic: AnyObject {
    func loadInitial()
    func loadOlder()
    func sendText(_ text: String)
    func sendPhoto(_ image: UIImage)
}

final class ChatInteractor: ChatBusinessLogic {
    private let company: Company
    private let currentUserId: Int
    private var messages: [ChatMessageView] = []
    private var hasMore = true
    private var isLoading = false
    private var currentProfile = ChatCurrentUserProfile(id: 0, username: "Вы", avatarURL: nil)

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

        Task {
            do {
                if let profile = try? await worker.fetchCurrentProfile() {
                    currentProfile = profile
                }
                let page = try await worker.listMessages(companyId: company.id, beforeId: nil, limit: 20)
                messages = page.items
                    .sorted(by: { $0.id < $1.id })
                    .map { message in
                        if message.isOutgoing {
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
                        return message
                    }
                hasMore = page.hasMore
                await MainActor.run {
                    self.presenter?.presentLoading(false)
                    self.presenter?.presentMessages(self.messages, hasMore: self.hasMore, animate: false)
                    self.isLoading = false
                }
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
        guard let oldestID = messages.first?.id else { return }
        isLoading = true
        presenter?.presentPaging(true)

        Task {
            do {
                let page = try await worker.listMessages(companyId: company.id, beforeId: oldestID, limit: 20)
                let older = page.items.sorted(by: { $0.id < $1.id })
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
                try await worker?.sendMessage(companyId: company.id, text: clean)
            } catch {
                await MainActor.run {
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
                try await worker?.sendMessagePhoto(companyId: company.id, image: image)
            } catch {
                await MainActor.run {
                    self.presenter?.presentError(error.localizedDescription)
                }
            }
        }
    }

    private func makeLocalMessage(kind: ChatMessageKind) -> ChatMessageView {
        ChatMessageView(
            id: Int(Date().timeIntervalSince1970 * 1000),
            senderId: currentProfile.id == 0 ? currentUserId : currentProfile.id,
            senderName: currentProfile.username,
            senderAvatarURL: currentProfile.avatarURL,
            sentAt: Date(),
            kind: kind,
            isOutgoing: true
        )
    }
}
