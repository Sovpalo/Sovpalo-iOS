import UIKit

protocol MeetingsPresenterProtocol: AnyObject {
    func presentLoading(_ isLoading: Bool)
    func presentMeetings(_ meetings: [Meeting])
    func presentOfflineMode(_ isOffline: Bool)
    func presentError(_ message: String)
    func presentAttendanceUpdated(for eventId: Int, status: MeetingResponseStatus, currentUsername: String?)
    func presentAttendanceSummaryUpdated(
        for eventId: Int,
        status: MeetingResponseStatus,
        attendeesGoing: [String],
        attendeesNotGoing: [String],
        currentUsername: String?
    )
    func routeToMeetingInfo(companyId: Int, meetingId: Int, initialMeeting: Meeting)
}

final class MeetingsPresenter: MeetingsPresenterProtocol {
    weak var vc: MeetingsVC?

    func presentLoading(_ isLoading: Bool) {
        DispatchQueue.main.async { [weak vc] in
            vc?.setLoading(isLoading)
        }
    }

    func presentMeetings(_ meetings: [Meeting]) {
        DispatchQueue.main.async { [weak vc] in
            vc?.applyMeetings(meetings)
        }
    }

    func presentOfflineMode(_ isOffline: Bool) {
        DispatchQueue.main.async { [weak vc] in
            vc?.setOfflineMode(isOffline)
        }
    }

    func presentError(_ message: String) {
        DispatchQueue.main.async { [weak vc] in
            vc?.showError(message: message)
        }
    }

    func presentAttendanceUpdated(for eventId: Int, status: MeetingResponseStatus, currentUsername: String?) {
        DispatchQueue.main.async { [weak vc] in
            vc?.applyAttendanceStatus(eventId: eventId, status: status, currentUsername: currentUsername)
        }
    }

    func presentAttendanceSummaryUpdated(
        for eventId: Int,
        status: MeetingResponseStatus,
        attendeesGoing: [String],
        attendeesNotGoing: [String],
        currentUsername: String?
    ) {
        DispatchQueue.main.async { [weak vc] in
            vc?.applyAttendanceSummary(
                eventId: eventId,
                status: status,
                attendeesGoing: attendeesGoing,
                attendeesNotGoing: attendeesNotGoing,
                currentUsername: currentUsername
            )
        }
    }

    func routeToMeetingInfo(companyId: Int, meetingId: Int, initialMeeting: Meeting) {
        DispatchQueue.main.async { [weak vc] in
            let infoVC = InfoMeetingAssembly.assembly(
                companyId: companyId,
                meetingId: meetingId,
                initialMeeting: initialMeeting
            )
            vc?.navigationController?.pushViewController(infoVC, animated: true)
        }
    }
}
