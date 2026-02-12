public extension PorbyConfiguration {
    /// Minimal overhead. Warning+ only, crash & lifecycle collectors.
    static let minimal: PorbyConfiguration = {
        var config = PorbyConfiguration()
        config.filter.minimumLevel = .warning
        config.enabledCollectors = [.crash, .lifecycle]
        config.limits.maxBufferCount = 100
        config.limits.maxLogsPerSecond = 100
        return config
    }()

    /// Full-featured development mode. All collectors, no pairing.
    static let development: PorbyConfiguration = {
        var config = PorbyConfiguration()
        config.filter.minimumLevel = .verbose
        config.enabledCollectors = .all
        config.limits.maxBufferCount = 1_000
        config.limits.maxLogsPerSecond = 1_000
        config.transport.requiresPairing = false
        return config
    }()

    /// CI testing: no transport, persistence only.
    static let ciTesting: PorbyConfiguration = {
        var config = PorbyConfiguration()
        config.filter.minimumLevel = .debug
        config.enabledCollectors = [.crash]
        config.persistence.isEnabled = true
        config.limits.maxBufferCount = 500
        return config
    }()

    /// Production: info+, crash & lifecycle, pairing enforced.
    static let production: PorbyConfiguration = {
        var config = PorbyConfiguration()
        config.filter.minimumLevel = .info
        config.enabledCollectors = [.crash, .lifecycle]
        config.limits.maxBufferCount = 500
        config.limits.maxLogsPerSecond = 200
        config.transport.requiresPairing = true
        return config
    }()
}
