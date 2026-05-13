//
//  SceneDelegate.swift
//  Sovpalo
//
//  Created by Vladimir Grigoryev on 28.10.2025.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        let keychainService = KeychainService()
        let tokenKey = "auth.token"
        
        let incomingTelegramAuthURL = connectionOptions.urlContexts
            .map { $0.url }
            .first(where: { !extractTelegramAuthPayload(from: $0).isEmpty })

        var rootVC: UIViewController
        if let data = keychainService.getData(forKey: tokenKey),
           let token = String(data: data, encoding: .utf8),
           let expDate = decodeJWTExpiration(token),
           expDate > Date() {
            print("[SceneDelegate] Found valid auth token in Keychain. Opening FirstGroup.")
            rootVC = FirstGroupAssembly.assembly()
        } else if incomingTelegramAuthURL != nil {
            print("[SceneDelegate] Opening Register screen for Telegram auth callback.")
            rootVC = RegisterAssembly.assembly()
        } else {
            print("[SceneDelegate] Auth token is missing or expired. Opening Start screen.")
            rootVC = StartAssembly.assembly()
        }
        
        let nav = UINavigationController(rootViewController: rootVC)
        window.overrideUserInterfaceStyle = .light
        nav.overrideUserInterfaceStyle = .light
        window.rootViewController = nav
        self.window = window
        window.makeKeyAndVisible()

        if let incomingTelegramAuthURL {
            handleIncomingTelegramAuthURL(incomingTelegramAuthURL)
        }
    }
    
    /// Decoding payload JWT and returning "exp" Date
    func decodeJWTExpiration(_ token: String) -> Date? {
        let segments = token.split(separator: ".")
        guard segments.count > 1 else { return nil }

        // JWT payload is base64url-encoded.
        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let payloadData = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? TimeInterval
        else {
            print("[SceneDelegate] Failed to decode JWT expiration.")
            return nil
        }

        return Date(timeIntervalSince1970: exp)
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleIncomingTelegramAuthURL(url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }
        handleIncomingTelegramAuthURL(url)
    }

}

private extension SceneDelegate {
    func handleIncomingTelegramAuthURL(_ url: URL) {
        let authPayload = extractTelegramAuthPayload(from: url)
        guard !authPayload.isEmpty else { return }
        TelegramAuthCallbackCenter.publish(payload: authPayload)
    }

    func extractTelegramAuthPayload(from url: URL) -> [String: String] {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var payload: [String: String] = [:]

        appendTelegramAuthFields(from: components?.queryItems, to: &payload)
        appendTelegramAuthFields(from: queryItems(from: components?.percentEncodedFragment), to: &payload)

        for parameterString in [components?.percentEncodedQuery, components?.percentEncodedFragment] {
            if let initData = extractRawTelegramInitData(from: parameterString) {
                payload["init_data"] = initData
                break
            }
        }

        return payload
    }

    func appendTelegramAuthFields(from queryItems: [URLQueryItem]?, to payload: inout [String: String]) {
        let allowedKeys = Set([
            "id",
            "first_name",
            "last_name",
            "username",
            "photo_url",
            "auth_date",
            "hash"
        ])

        for item in queryItems ?? [] where !item.name.isEmpty {
            guard let value = item.value, !value.isEmpty else { continue }
            switch item.name {
            case "init_data", "initData", "tgWebAppData":
                payload["init_data"] = value
            case let key where allowedKeys.contains(key):
                payload[key] = value
            default:
                continue
            }
        }
    }

    func queryItems(from percentEncodedParameterString: String?) -> [URLQueryItem] {
        guard let percentEncodedParameterString,
              !percentEncodedParameterString.isEmpty else {
            return []
        }

        var components = URLComponents()
        components.percentEncodedQuery = percentEncodedParameterString
        return components.queryItems ?? []
    }

    func extractRawTelegramInitData(from percentEncodedParameterString: String?) -> String? {
        guard let percentEncodedParameterString else { return nil }
        for name in ["init_data", "initData", "tgWebAppData"] {
            guard let rawValue = rawValue(for: name, in: percentEncodedParameterString),
                  !rawValue.isEmpty else { continue }
            return rawValue.removingPercentEncoding ?? rawValue
        }
        return nil
    }

    func rawValue(for name: String, in percentEncodedParameterString: String) -> String? {
        let prefix = name + "="
        return percentEncodedParameterString
            .split(separator: "&", omittingEmptySubsequences: false)
            .first(where: { $0.hasPrefix(prefix) })
            .map { String($0.dropFirst(prefix.count)) }
    }
}

enum TelegramAuthCallbackCenter {
    private static var pendingPayload: [String: String]?

    static func publish(payload: [String: String]) {
        pendingPayload = payload
        NotificationCenter.default.post(
            name: .telegramAuthInitDataReceived,
            object: nil,
            userInfo: payload
        )
    }

    static func takePendingPayload() -> [String: String]? {
        guard let pendingPayload else { return nil }
        self.pendingPayload = nil
        return pendingPayload
    }

    static func clearPendingPayload() {
        pendingPayload = nil
    }
}

extension Notification.Name {
    static let telegramAuthInitDataReceived = Notification.Name("telegramAuthInitDataReceived")
}
