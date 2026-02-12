import Foundation

/// Singleton engine that ties together buffer + transport + configuration
final class LogEngine {
    static let shared = LogEngine()

    private var buffer: LogBuffer
    private let transport: TransportLayer
    private let queue = DispatchQueue(label: "com.porby.engine", qos: .utility)

    private(set) var isRunning = false
    private(set) var configuration: PorbyConfiguration = .default

    var onConnectionChanged: ((ConnectionState) -> Void)?

    private init() {
        self.buffer = LogBuffer()
        self.transport = TransportLayer()
    }

    func start(configuration: PorbyConfiguration) {
        guard !isRunning else { return }
        self.configuration = configuration

        // Validate and print warnings
        let warnings = configuration.validate()
        for w in warnings {
            print("[PorbySDK] ⚠️ \(w.key): \(w.message)")
        }

        // Debug-only enforcement
        if configuration.enforceDebugOnly {
            #if !DEBUG
            print("[PorbySDK] SDK disabled in non-DEBUG build (enforceDebugOnly=true)")
            return
            #endif
        }

        guard configuration.isEnabled else { return }
        isRunning = true

        // Reinitialize buffer with configured max size
        buffer = LogBuffer(maxSize: configuration.limits.maxBufferCount)

        transport.onConnectionChanged = { [weak self] state in
            self?.onConnectionChanged?(state)
        }

        try? transport.start(configuration: configuration)

        buffer.startFlushing(interval: configuration.limits.flushInterval) { [weak self] entries in
            self?.transport.send(entries)
        }
    }

    func stop() {
        isRunning = false
        buffer.flush()
        transport.stop()
    }

    func shouldLog(level: PorbyLogLevel, category: PorbyCategory) -> Bool {
        guard isRunning, configuration.isEnabled else { return false }
        return configuration.filter.shouldLog(level: level, category: category)
    }

    func ingest(_ entry: PorbyLogEntry) {
        queue.async { [weak self] in
            self?.buffer.append(entry)
        }
    }

    var isConnected: Bool { transport.isConnected }
}
