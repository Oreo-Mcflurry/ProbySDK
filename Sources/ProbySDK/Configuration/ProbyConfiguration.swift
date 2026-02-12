import Foundation

// MARK: - ProbyConfiguration

public struct ProbyConfiguration: Sendable {

    // MARK: - Top-level

    /// SDK kill switch. false = all log() calls are no-op.
    public var isEnabled: Bool = true

    /// App name shown in viewer. nil = Bundle CFBundleName auto-detection.
    public var appName: String? = nil

    /// Block SDK start in non-DEBUG builds.
    public var enforceDebugOnly: Bool = true

    // MARK: - Sub-configurations

    public var filter = Filter()
    public var enabledCollectors: EnabledCollectors = .all
    public var transport = Transport()
    public var persistence = Persistence()
    public var privacy = Privacy()
    public var limits = Limits()

    // MARK: - Static Helpers

    public static let `default` = ProbyConfiguration()

    public var resolvedAppName: String {
        appName ?? Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "App"
    }

    public init() {}
}

// MARK: - Filter

public extension ProbyConfiguration {
    struct Filter: Sendable {
        /// Global minimum log level. Logs below this are ignored.
        public var minimumLevel: ProbyLogLevel = .verbose

        /// Per-category minimum level override.
        public var categoryLevels: [ProbyCategory: ProbyLogLevel] = [:]

        /// Completely disabled categories.
        public var disabledCategories: Set<ProbyCategory> = []

        public init() {}

        public func shouldLog(level: ProbyLogLevel, category: ProbyCategory) -> Bool {
            guard !disabledCategories.contains(category) else { return false }
            if let categoryLevel = categoryLevels[category] {
                return level >= categoryLevel
            }
            return level >= minimumLevel
        }
    }
}

// MARK: - EnabledCollectors (OptionSet)

public extension ProbyConfiguration {
    struct EnabledCollectors: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let network     = EnabledCollectors(rawValue: 1 << 0)
        public static let crash       = EnabledCollectors(rawValue: 1 << 1)
        public static let ui          = EnabledCollectors(rawValue: 1 << 2)
        public static let performance = EnabledCollectors(rawValue: 1 << 3)
        public static let lifecycle   = EnabledCollectors(rawValue: 1 << 4)

        public static let all: EnabledCollectors = [.network, .crash, .ui, .performance, .lifecycle]
    }
}

// MARK: - Transport

public extension ProbyConfiguration {
    struct Transport: Sendable {
        /// WebSocket server port. Default 9394.
        public var port: UInt16 = 9394

        /// Bonjour service name. nil = anonymized device model name.
        public var bonjourServiceName: String? = nil

        /// Anonymize device name in mDNS. true = model only (e.g. "iPhone").
        public var anonymizesDeviceName: Bool = true

        /// Include app name in mDNS advertisement.
        public var advertisesAppName: Bool = false

        /// Maximum simultaneous viewer connections.
        public var maxViewerConnections: Int = 3

        /// Auto-reconnect on disconnect.
        public var reconnectsAutomatically: Bool = true

        /// Heartbeat interval (seconds).
        public var heartbeatInterval: TimeInterval = 30

        /// Require pairing code authentication.
        public var requiresPairing: Bool = true

        /// Manual pairing code. nil = auto-generate 6-digit PIN.
        public var pairingCode: String? = nil

        /// Max pairing attempts before cooldown.
        public var maxPairingAttempts: Int = 3

        /// Cooldown after max pairing failures (seconds).
        public var pairingCooldown: TimeInterval = 30

        public init() {}
    }
}

// MARK: - Persistence

public extension ProbyConfiguration {
    struct Persistence: Sendable {
        /// Enable offline log storage. Default false (opt-in).
        public var isEnabled: Bool = false

        /// Max file size in bytes.
        public var maxFileSize: Int = 10 * 1024 * 1024  // 10MB

        /// Max file count for rotation.
        public var maxFileCount: Int = 3

        /// Max retention interval.
        public var maxRetentionInterval: TimeInterval = 24 * 60 * 60  // 24h

        /// Auto-send stored logs on viewer connect.
        public var flushesOnConnect: Bool = true

        /// Max entries to replay.
        public var maxReplayEntries: Int = 5_000

        /// iOS Data Protection level.
        public var fileProtection: FileProtectionLevel = .completeUntilFirstUserAuthentication

        public init() {}
    }

    enum FileProtectionLevel: Sendable {
        case completeUntilFirstUserAuthentication
        case complete
    }
}

// MARK: - Privacy

public extension ProbyConfiguration {
    struct Privacy: Sendable {
        /// HTTP headers to redact (case-insensitive).
        public var redactedHeaderNames: Set<String> = Self.defaultRedactedHeaders

        /// Metadata keys to redact (case-insensitive).
        public var redactedMetadataKeys: Set<String> = Self.defaultRedactedKeys

        /// URL query parameters to redact.
        public var redactedQueryParams: Set<String> = ["token", "key", "secret", "password", "api_key"]

        /// Max body capture size in bytes. 0 = disable body capture.
        public var maxBodySize: Int = 10 * 1024  // 10KB

        /// Redaction placeholder string.
        public var redactionPlaceholder: String = "[REDACTED]"

        public init() {}

        public static let defaultRedactedHeaders: Set<String> = [
            "Authorization", "Proxy-Authorization",
            "X-API-Key", "X-Auth-Token",
            "Cookie", "Set-Cookie",
            "X-CSRF-Token", "X-XSRF-Token",
            "X-Request-ID", "X-Correlation-ID",
            "X-Forwarded-For", "X-Real-IP",
        ]

        public static let defaultRedactedKeys: Set<String> = [
            "password", "passwd", "pwd",
            "secret", "secret_key", "secretKey",
            "token", "access_token", "accessToken",
            "refresh_token", "refreshToken",
            "api_key", "apiKey", "api_secret", "apiSecret",
            "ssn", "social_security",
            "credit_card", "creditCard", "card_number",
            "private_key", "privateKey",
        ]
    }
}

// MARK: - Limits

public extension ProbyConfiguration {
    struct Limits: Sendable {
        /// Max log buffer entries in memory.
        public var maxBufferCount: Int = 1_000

        /// Batch flush interval (seconds). Clamped 16ms-5s.
        public var flushInterval: TimeInterval = 0.1

        /// Max logs per second. 0 = unlimited. error/fatal exempt.
        public var maxLogsPerSecond: Int = 1_000

        /// Performance metrics collection interval.
        public var performanceMonitoringInterval: TimeInterval = 5.0

        /// Background behavior policy.
        public var backgroundPolicy: BackgroundPolicy = .pause

        public init() {}
    }

    enum BackgroundPolicy: Sendable {
        case pause
        case reduce
        case `continue`
    }
}

// MARK: - Convenience Extensions

public extension Int {
    static func kilobytes(_ kb: Int) -> Int { kb * 1_024 }
    static func megabytes(_ mb: Int) -> Int { mb * 1_024 * 1_024 }
}

public extension TimeInterval {
    static func minutes(_ m: Double) -> TimeInterval { m * 60 }
    static func hours(_ h: Double) -> TimeInterval { h * 3_600 }
    static func days(_ d: Double) -> TimeInterval { d * 86_400 }
}
