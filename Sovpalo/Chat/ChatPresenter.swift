import Foundation

protocol ChatPresenterProtocol: AnyObject {
    func presentMessages(_ messages: [ChatMessageView], hasMore: Bool, animate: Bool)
    func presentLoading(_ isLoading: Bool)
    func presentPaging(_ isLoadingOlder: Bool)
    func presentError(_ message: String)
    func presentConnectionState(_ state: ChatWebSocketState)
}

final class ChatPresenter: ChatPresenterProtocol {
    weak var vc: ChatViewController?

    func presentMessages(_ messages: [ChatMessageView], hasMore: Bool, animate: Bool) {
        DispatchQueue.main.async { [weak vc] in
            vc?.apply(messages: messages, hasMore: hasMore, animate: animate)
        }
    }

    func presentLoading(_ isLoading: Bool) {
        DispatchQueue.main.async { [weak vc] in
            vc?.setInitialLoading(isLoading)
        }
    }

    func presentPaging(_ isLoadingOlder: Bool) {
        DispatchQueue.main.async { [weak vc] in
            vc?.setLoadingOlder(isLoadingOlder)
        }
    }

    func presentError(_ message: String) {
        DispatchQueue.main.async { [weak vc] in
            vc?.showError(message)
        }
    }

    func presentConnectionState(_ state: ChatWebSocketState) {
        DispatchQueue.main.async { [weak vc] in
            vc?.setConnectionState(state)
        }
    }
}
