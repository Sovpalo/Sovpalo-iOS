//
//  PushNotificationManager.swift
//  Sovpalo
//

import Foundation
import UIKit
import UserNotifications

enum PushDeviceTokenAPIError: Error {
    case invalidURL
    case badStatus(Int)
}

private struct PushTokenRegisterBody: Encodable {
    let token: String
    let platform: String
}

private struct PushTokenDeleteBody: Encodable {
    let token: String
}

enum PushDeviceTokenAPI {
    private static let path = "/auth/me/push-tokens"

    static func register(hexToken: String, bearer: String) async throws {
        guard let url = URL(string: Server.url + path) else { throw PushDeviceTokenAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(PushTokenRegisterBody(token: hexToken, platform: "ios"))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PushDeviceTokenAPIError.badStatus(-1) }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[Push] POST \(path) failed status=\(http.statusCode) body=\(body.prefix(500))")
            throw PushDeviceTokenAPIError.badStatus(http.statusCode)
        }
    }

    static func delete(bearer: String, hexToken: String) async throws {
        guard let url = URL(string: Server.url + path) else { throw PushDeviceTokenAPIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(PushTokenDeleteBody(token: hexToken))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PushDeviceTokenAPIError.badStatus(-1) }
        guard (200...299).contains(http.statusCode) || http.statusCode == 204 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("[Push] DELETE \(path) failed status=\(http.statusCode) body=\(body.prefix(500))")
            throw PushDeviceTokenAPIError.badStatus(http.statusCode)
        }
    }
}

private extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}

/// Registers for APNs, uploads device token to `POST /auth/me/push-tokens`, removes on logout.
final class PushNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationManager()

    private let keychain: KeychainLogic
    private var pendingHexToken: String?
    private let defaultsKey = "sov.pendingPushDeviceTokenHex"
    private let lastRegisteredTokenKey = "sov.lastRegisteredPushDeviceTokenHex"

    private override init() {
        self.keychain = KeychainService()
        super.init()
    }

    func configureAtLaunch() {
        UNUserNotificationCenter.current().delegate = self
        if let saved = UserDefaults.standard.string(forKey: defaultsKey), !saved.isEmpty {
            pendingHexToken = saved
        }
    }

    /// Call after login / cold start with session so the user gets the permission prompt and APNs registration.
    func registerForPushNotificationsIfLoggedIn() {
        guard currentBearer() != nil else { return }

        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let status = settings.authorizationStatus
            print("[Push] notification authorization status: \(String(describing: status))")

            switch status {
            case .denied:
                print("[Push] Уведомления выключены в Настройках → приложение не получит APNs token. Включите Sovpalo → Уведомления.")
                return

            case .authorized, .provisional, .ephemeral:
                // Не полагаемся на повторный requestAuthorization — сразу регистрируемся в APNs.
                UIApplication.shared.registerForRemoteNotifications()

            case .notDetermined:
                do {
                    let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                    guard granted else {
                        print("[Push] User declined notification permission prompt")
                        return
                    }
                    UIApplication.shared.registerForRemoteNotifications()
                } catch {
                    print("[Push] requestAuthorization error: \(error)")
                }

            @unknown default:
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func applicationDidReceiveDeviceToken(_ deviceToken: Data) {
        let hex = deviceToken.hexEncodedString()
        print("[Push] APNs device token received, hex length=\(hex.count)")

        guard let bearer = currentBearer() else {
            pendingHexToken = hex
            UserDefaults.standard.set(hex, forKey: defaultsKey)
            print("[Push] Stored pending device token (no auth session yet)")
            return
        }

        Task {
            await upload(hex: hex, bearer: bearer)
        }
    }

    func applicationDidFailToRegisterForRemoteNotifications(error: Error) {
        print("[Push] didFailToRegisterForRemoteNotifications: \(error.localizedDescription)")
    }

    /// After auth token is saved, upload any token we already received.
    func flushPendingDeviceTokenIfNeeded() {
        let hex = pendingHexToken ?? UserDefaults.standard.string(forKey: defaultsKey)
        guard let hex, !hex.isEmpty, let bearer = currentBearer() else { return }

        Task {
            await upload(hex: hex, bearer: bearer)
        }
    }

    /// Remove server-side token before clearing session (best-effort).
    func deletePushTokenFromServer(bearer: String) async {
        guard let hex = UserDefaults.standard.string(forKey: lastRegisteredTokenKey), !hex.isEmpty else {
            print("[Push] No stored device token to delete on server")
            return
        }
        do {
            try await PushDeviceTokenAPI.delete(bearer: bearer, hexToken: hex)
            print("[Push] Server push token removed")
        } catch {
            print("[Push] delete push token failed: \(error)")
        }
    }

    func clearLocalPushState() {
        pendingHexToken = nil
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        UserDefaults.standard.removeObject(forKey: lastRegisteredTokenKey)
        Task { @MainActor in
            UIApplication.shared.unregisterForRemoteNotifications()
        }
    }

    private func currentBearer() -> String? {
        guard let data = keychain.getData(forKey: "auth.token") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func upload(hex: String, bearer: String) async {
        do {
            try await PushDeviceTokenAPI.register(hexToken: hex, bearer: bearer)
            pendingHexToken = nil
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            UserDefaults.standard.set(hex, forKey: lastRegisteredTokenKey)
            print("[Push] Device token registered with backend")
        } catch {
            print("[Push] register push token failed: \(error)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            PushNotificationRouter.handleNotificationResponse(response)
        }
        completionHandler()
    }
}
