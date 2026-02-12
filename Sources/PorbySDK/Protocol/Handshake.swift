import Foundation

/// Handshake payload sent from SDK to viewer on connection
public struct Handshake: Codable, Sendable {
    public let protocolVersion: UInt32
    public let sdkVersion: String
    public let deviceInfo: DeviceInfo
    public let appInfo: AppInfo
    public let pairingRequired: Bool
    public let sdkCapabilities: [String]

    public init(
        protocolVersion: UInt32 = 1,
        sdkVersion: String = "0.1.0",
        deviceInfo: DeviceInfo = .current(),
        appInfo: AppInfo = .current(),
        pairingRequired: Bool = true,
        sdkCapabilities: [String] = ["json"]
    ) {
        self.protocolVersion = protocolVersion
        self.sdkVersion = sdkVersion
        self.deviceInfo = deviceInfo
        self.appInfo = appInfo
        self.pairingRequired = pairingRequired
        self.sdkCapabilities = sdkCapabilities
    }
}

/// Device hardware/OS information
public struct DeviceInfo: Codable, Sendable {
    public let name: String
    public let model: String
    public let osVersion: String
    public let identifier: String

    public init(name: String, model: String, osVersion: String, identifier: String) {
        self.name = name
        self.model = model
        self.osVersion = osVersion
        self.identifier = identifier
    }
}

/// Application metadata
public struct AppInfo: Codable, Sendable {
    public let name: String
    public let bundleId: String
    public let version: String
    public let build: String
    public let environment: AppEnvironment

    public init(name: String, bundleId: String, version: String, build: String, environment: AppEnvironment) {
        self.name = name
        self.bundleId = bundleId
        self.version = version
        self.build = build
        self.environment = environment
    }
}

/// App build environment
public enum AppEnvironment: String, Codable, Sendable {
    case debug
    case testFlight
    case release
}
