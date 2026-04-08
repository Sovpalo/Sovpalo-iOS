import Foundation

enum AppSecrets {
    private static let fileName = "secret"
    private static let fileExtension = "plist"

    static func appMetricaAPIKey() -> String? {
        stringValue(forKey: "APPMETRICA_API_KEY")
    }

    static func boolValue(forKey key: String, default defaultValue: Bool = false) -> Bool {
        guard let value = value(forKey: key) else { return defaultValue }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let stringValue = value as? String {
            switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1":
                return true
            case "false", "no", "0":
                return false
            default:
                return defaultValue
            }
        }

        return defaultValue
    }

    static func stringValue(forKey key: String) -> String? {
        guard let secrets = dictionary() else { return nil }
        guard let rawValue = secrets[key] as? String else {
            print("[AppSecrets] \(key) is missing in \(fileName).\(fileExtension).")
            return nil
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            print("[AppSecrets] \(key) is empty in \(fileName).\(fileExtension).")
            return nil
        }

        if value.contains("PASTE_") || value.contains("YOUR_") {
            print("[AppSecrets] \(key) still contains a placeholder value.")
            return nil
        }

        return value
    }

    static func value(forKey key: String) -> Any? {
        dictionary()?[key]
    }

    private static func dictionary() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            print("[AppSecrets] \(fileName).\(fileExtension) was not found in the app bundle.")
            return nil
        }

        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dictionary = plist as? [String: Any]
        else {
            print("[AppSecrets] Failed to decode \(fileName).\(fileExtension).")
            return nil
        }

        return dictionary
    }
}
