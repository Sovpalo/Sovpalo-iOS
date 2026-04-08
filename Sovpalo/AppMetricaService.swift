import AppMetricaCore
import Foundation

enum AppMetricaEvent {
    static let userRegistered = "user_registered"
    static let userSignedIn = "user_signed_in"
    static let userLoggedOut = "user_logged_out"
    static let companyCreated = "company_created"
    static let companyInvitationSent = "company_invitation_sent"
    static let companyInvitationAccepted = "company_invitation_accepted"
    static let companyInvitationDeclined = "company_invitation_declined"
    static let companyMemberRemoved = "company_member_removed"
    static let meetingCreated = "meeting_created"
    static let meetingUpdated = "meeting_updated"
    static let meetingDeleted = "meeting_deleted"
    static let ideaCreated = "idea_created"
    static let ideaLikeToggled = "idea_like_toggled"
    static let availabilityUpdated = "availability_updated"
    static let passwordResetRequested = "password_reset_requested"
    static let verificationCompleted = "verification_completed"
}

enum AppMetricaService {
    static func activate() {
        guard let apiKey = AppSecrets.appMetricaAPIKey() else {
            print("[AppMetricaService] SDK activation skipped because API key is not configured.")
            return
        }

        guard !AppMetrica.isActivated else {
            print("[AppMetricaService] AppMetrica is already activated.")
            refreshUserProfileID()
            return
        }

        guard let configuration = AppMetricaConfiguration(apiKey: apiKey) else {
            print("[AppMetricaService] Failed to create AppMetricaConfiguration.")
            return
        }

        configuration.handleActivationAsSessionStart = true
        configuration.areLogsEnabled = AppSecrets.boolValue(
            forKey: "APPMETRICA_LOGS_ENABLED",
            default: false
        )

        print("[AppMetricaService] Activating AppMetrica. Logs enabled: \(configuration.areLogsEnabled)")
        AppMetrica.activate(with: configuration)
        print("[AppMetricaService] AppMetrica activation finished.")
        refreshUserProfileID()
    }

    static func refreshUserProfileID() {
        guard
            let userIdData = KeychainService().getData(forKey: "auth.userId"),
            let userId = String(data: userIdData, encoding: .utf8),
            !userId.isEmpty
        else {
            print("[AppMetricaService] userProfileID is not available yet.")
            return
        }

        AppMetrica.userProfileID = userId
        print("[AppMetricaService] userProfileID updated: \(userId)")
    }

    static func reportEvent(
        _ name: String,
        parameters: [String: Any?] = [:],
        flushImmediately: Bool = true
    ) {
        let filteredParameters = parameters.reduce(into: [String: Any]()) { result, item in
            guard let value = item.value else { return }
            result[item.key] = value
        }

        print("[AppMetricaService] Reporting event '\(name)' with parameters: \(filteredParameters)")
        AppMetrica.reportEvent(name: name, parameters: filteredParameters, onFailure: { error in
            print("[AppMetricaService] Failed to report \(name): \(error.localizedDescription)")
        })

        if flushImmediately {
            print("[AppMetricaService] Flushing AppMetrica events buffer.")
            AppMetrica.sendEventsBuffer()
        }
    }
}
