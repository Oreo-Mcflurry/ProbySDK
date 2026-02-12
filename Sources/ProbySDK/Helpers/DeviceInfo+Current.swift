import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension DeviceInfo {
    /// Returns current device information
    public static func current() -> DeviceInfo {
        #if canImport(UIKit)
        let device = UIDevice.current
        return DeviceInfo(
            name: device.name,
            model: device.model,
            osVersion: "\(device.systemName) \(device.systemVersion)",
            identifier: identifierForVendor()
        )
        #else
        return DeviceInfo(
            name: Host.current().localizedName ?? "Mac",
            model: "Mac",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            identifier: UUID().uuidString
        )
        #endif
    }

    private static func identifierForVendor() -> String {
        #if canImport(UIKit)
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        UUID().uuidString
        #endif
    }
}
