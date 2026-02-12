import Foundation

extension AppInfo {
    /// Returns current app information from the main bundle
    public static func current() -> AppInfo {
        let info = Bundle.main.infoDictionary ?? [:]
        let name = info["CFBundleDisplayName"] as? String
            ?? info["CFBundleName"] as? String
            ?? "Unknown"
        let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
        let version = info["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info["CFBundleVersion"] as? String ?? "0"

        return AppInfo(
            name: name,
            bundleId: bundleId,
            version: version,
            build: build,
            environment: detectEnvironment()
        )
    }

    private static func detectEnvironment() -> AppEnvironment {
        #if DEBUG
        return .debug
        #else
        if let receiptURL = Bundle.main.appStoreReceiptURL,
           receiptURL.lastPathComponent == "sandboxReceipt" {
            return .testFlight
        }
        return .release
        #endif
    }
}
