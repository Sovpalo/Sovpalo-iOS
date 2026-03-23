import UIKit

protocol CreateMeetingPresenterProtocol {
    func presentSuccess()
    func presentError(message: String)
}

final class CreateMeetingPresenter: CreateMeetingPresenterProtocol {
    weak var vc: CreateMeetingVC?

    func presentSuccess() {
        vc?.showSuccessAndClose()
    }

    func presentError(message: String) {
        vc?.showError(message: message)
    }
}
