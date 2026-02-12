import Foundation

// MARK: - Configuration Validation

public extension ProbyConfiguration {

    /// A warning produced during configuration validation
    struct ConfigWarning: Sendable {
        public let key: String
        public let message: String

        public init(key: String, message: String) {
            self.key = key
            self.message = message
        }
    }

    /// Validate the configuration and return any warnings
    func validate() -> [ConfigWarning] {
        var warnings: [ConfigWarning] = []

        // Port below 1024 requires elevated privileges
        if transport.port > 0 && transport.port < 1024 {
            warnings.append(ConfigWarning(
                key: "transport.port",
                message: "Port \(transport.port) is below 1024 and may require elevated privileges."
            ))
        }

        // Flush interval bounds: 16ms – 5s
        if limits.flushInterval < 0.016 {
            warnings.append(ConfigWarning(
                key: "limits.flushInterval",
                message: "Flush interval \(limits.flushInterval)s is below 16ms minimum. This may cause excessive CPU usage."
            ))
        }
        if limits.flushInterval > 5.0 {
            warnings.append(ConfigWarning(
                key: "limits.flushInterval",
                message: "Flush interval \(limits.flushInterval)s exceeds 5s. Logs may appear delayed in the viewer."
            ))
        }

        // Persistence maxFileSize of 0 effectively disables persistence
        if persistence.isEnabled && persistence.maxFileSize == 0 {
            warnings.append(ConfigWarning(
                key: "persistence.maxFileSize",
                message: "maxFileSize is 0 while persistence is enabled. No logs will be persisted."
            ))
        }

        // Pairing disabled warning
        if !transport.requiresPairing {
            warnings.append(ConfigWarning(
                key: "transport.requiresPairing",
                message: "Pairing is disabled. Any device on the network can receive logs, which may expose sensitive data."
            ))
        }

        // maxBodyCaptureSize over 100KB
        if privacy.maxBodySize > 100 * 1024 {
            warnings.append(ConfigWarning(
                key: "privacy.maxBodySize",
                message: "maxBodyCaptureSize exceeds 100KB (\(privacy.maxBodySize) bytes). This may increase memory usage significantly."
            ))
        }

        return warnings
    }
}
