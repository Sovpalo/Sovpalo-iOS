import Foundation

enum OfflineTesting {
    static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-SovpaloOfflineMode")
        #else
        false
        #endif
    }

    static func throwIfNeeded() throws {
        if isEnabled {
            throw URLError(.notConnectedToInternet)
        }
    }
}
