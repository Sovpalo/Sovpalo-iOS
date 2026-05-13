//
//  PushNotificationRouting.swift
//  Sovpalo
//

import UIKit
import UserNotifications

extension Company {
    /// Shell company for deep links: only `id` is used for API; name is placeholder until user refreshes list.
    static func pushNavigationShell(companyId: Int) -> Company {
        let now = Date()
        return Company(
            id: companyId,
            name: "Компания",
            description: nil,
            avatarURL: nil,
            createdBy: 0,
            createdAt: now,
            updatedAt: now
        )
    }
}

enum RemotePushPayload {
    case chatMessage(companyId: Int, messageId: Int?)
    case event(companyId: Int, eventId: Int)

    init?(userInfo: [AnyHashable: Any]) {
        guard let rawType = userInfo["type"] else { return nil }
        let typeRaw: String
        if let s = rawType as? String {
            typeRaw = s
        } else if let s = rawType as? NSString {
            typeRaw = s as String
        } else {
            return nil
        }
        guard let companyId = Self.intValue(userInfo["company_id"]) else { return nil }

        switch typeRaw {
        case "chat_message":
            let messageId = Self.intValue(userInfo["message_id"]) ?? Self.intValue(userInfo["related_entity_id"])
            self = .chatMessage(companyId: companyId, messageId: messageId)
        case "event_created", "event_updated":
            guard let eventId = Self.intValue(userInfo["event_id"]) ?? Self.intValue(userInfo["related_entity_id"]) else {
                return nil
            }
            self = .event(companyId: companyId, eventId: eventId)
        default:
            return nil
        }
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let i as Int:
            return i
        case let n as NSNumber:
            return n.intValue
        case let s as String:
            return Int(s)
        case let s as NSString:
            return Int(s as String)
        default:
            return nil
        }
    }
}

enum PushNotificationRouter {
    private static func keyNavigationController() -> UINavigationController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first
        guard let root = window?.rootViewController else { return nil }
        return findNavigationController(from: root)
    }

    private static func findNavigationController(from vc: UIViewController) -> UINavigationController? {
        if let nav = vc as? UINavigationController { return nav }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return findNavigationController(from: selected)
        }
        for child in vc.children {
            if let nav = findNavigationController(from: child) { return nav }
        }
        if let presented = vc.presentedViewController {
            return findNavigationController(from: presented)
        }
        return nil
    }

    private static func hasAuthToken() -> Bool {
        let keychain = KeychainService()
        guard let data = keychain.getData(forKey: "auth.token"), !data.isEmpty else { return false }
        guard let token = String(data: data, encoding: .utf8), !token.isEmpty else { return false }
        if let exp = decodeJWTExpiration(token) {
            return exp > Date()
        }
        return true
    }

    /// Mirrors `SceneDelegate.decodeJWTExpiration` for session checks without importing SceneDelegate.
    private static func decodeJWTExpiration(_ token: String) -> Date? {
        let segments = token.split(separator: ".")
        guard segments.count > 1 else { return nil }
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
        else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    static func handleNotificationResponse(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        guard let payload = RemotePushPayload(userInfo: userInfo) else {
            print("[Push] Unrecognized notification payload")
            return
        }
        DispatchQueue.main.async {
            open(payload: payload)
        }
    }

    private static func open(payload: RemotePushPayload) {
        guard hasAuthToken() else {
            print("[Push] No valid session; skip deep link")
            return
        }
        guard let nav = keyNavigationController() else {
            print("[Push] No navigation controller for deep link")
            return
        }

        let companyId: Int
        let company: Company
        let eventIdForRoute: Int?
        switch payload {
        case let .chatMessage(cid, _):
            companyId = cid
            company = .pushNavigationShell(companyId: cid)
            eventIdForRoute = nil
        case let .event(cid, eid):
            companyId = cid
            company = .pushNavigationShell(companyId: cid)
            eventIdForRoute = eid
        }

        if let tab = nav.viewControllers.compactMap({ $0 as? MainTabBarController }).last(where: { $0.selectedCompany.id == companyId }) {
            switch payload {
            case .chatMessage:
                tab.selectedIndex = TabBar.Tab.chat.rawValue
            case .event:
                guard let eventId = eventIdForRoute else { return }
                tab.selectedIndex = TabBar.Tab.calendar.rawValue
                guard let meetingsNav = tab.viewControllers?[TabBar.Tab.calendar.rawValue] as? UINavigationController else { return }
                meetingsNav.popToRootViewController(animated: false)
                let info = InfoMeetingAssembly.assembly(companyId: companyId, meetingId: eventId, initialMeeting: nil)
                meetingsNav.pushViewController(info, animated: true)
            }
            return
        }

        let tab = MainTabBarController(selectedCompany: company)
        tab.loadViewIfNeeded()
        nav.setViewControllers([tab], animated: true)

        switch payload {
        case .chatMessage:
            tab.selectedIndex = TabBar.Tab.chat.rawValue
        case .event:
            guard let eventId = eventIdForRoute else { return }
            tab.selectedIndex = TabBar.Tab.calendar.rawValue
            guard let meetingsNav = tab.viewControllers?[TabBar.Tab.calendar.rawValue] as? UINavigationController else { return }
            let info = InfoMeetingAssembly.assembly(companyId: companyId, meetingId: eventId, initialMeeting: nil)
            meetingsNav.pushViewController(info, animated: true)
        }
    }
}
