import Foundation

protocol MeetingsPresenterProtocol: AnyObject {
    func presentMeetings(_ meetings: [Meeting])
    func presentError(_ message: String)
    func presentAttendanceUpdated(for eventId: Int, status: MeetingResponseStatus)
}

final class MeetingsPresenter: MeetingsPresenterProtocol {
    weak var vc: MeetingsVC?

    func presentMeetings(_ meetings: [Meeting]) {
        DispatchQueue.main.async { [weak vc] in
            vc?.applyMeetings(meetings)
        }
    }

    func presentError(_ message: String) {
        DispatchQueue.main.async { [weak vc] in
            vc?.showError(message: message)
        }
    }

    func presentAttendanceUpdated(for eventId: Int, status: MeetingResponseStatus) {
        DispatchQueue.main.async { [weak vc] in
            vc?.applyAttendanceStatus(eventId: eventId, status: status)
        }
    }
}
