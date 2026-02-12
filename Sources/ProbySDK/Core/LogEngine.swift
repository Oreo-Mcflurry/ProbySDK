import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Singleton engine that ties together buffer + transport + configuration
final class LogEngine {
    static let shared = LogEngine()

    private var buffer: LogBuffer
    private let transport: TransportLayer
    private let queue = DispatchQueue(label: "com.proby.engine", qos: .utility)
    private var collectors: [LogCollector] = []

    private(set) var isRunning = false
    private(set) var configuration: ProbyConfiguration = .default

    var onConnectionChanged: ((ConnectionState) -> Void)?

    // MARK: - Rate Limiting State

    private var logCountThisSecond: Int = 0
    private var lastSecondTimestamp: Date = Date()
    private let rateLimitLock = NSLock()

    // MARK: - Memory Pressure State

    private var memoryWarningObserver: Any?
    private let estimatedEntrySize = 512 // bytes per entry estimate
    private let memoryHardCapBytes = 5 * 1024 * 1024 // 5MB

    private init() {
        self.buffer = LogBuffer()
        self.transport = TransportLayer()
    }

    func start(configuration: ProbyConfiguration) {
        guard !isRunning else { return }
        self.configuration = configuration

        // Validate and print warnings
        let warnings = configuration.validate()
        for w in warnings {
            print("[ProbySDK] ⚠️ \(w.key): \(w.message)")
        }

        // Debug-only enforcement
        if configuration.enforceDebugOnly {
            #if !DEBUG
            print("[ProbySDK] SDK disabled in non-DEBUG build (enforceDebugOnly=true)")
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

        // Register enabled auto-collectors
        let enabled = configuration.enabledCollectors
        if enabled.contains(.network)     { register(NetworkCollector()) }
        if enabled.contains(.lifecycle)   { register(LifecycleCollector()) }
        if enabled.contains(.ui)          { register(UICollector()) }
        if enabled.contains(.performance) { register(PerformanceCollector(interval: configuration.limits.performanceMonitoringInterval)) }
        if enabled.contains(.crash)       { register(CrashCollector()) }

        // Observe memory warnings
        observeMemoryWarnings()
    }

    func stop() {
        isRunning = false
        collectors.forEach { $0.stop() }
        collectors.removeAll()
        buffer.flush()
        transport.stop()
        removeMemoryWarningObserver()
    }

    func shouldLog(level: ProbyLogLevel, category: ProbyCategory) -> Bool {
        guard isRunning, configuration.isEnabled else { return false }
        return configuration.filter.shouldLog(level: level, category: category)
    }

    func ingest(_ entry: ProbyLogEntry) {
        // Rate limiting: error/fatal are always allowed through
        let isPriority = entry.level == .error || entry.level == .fatal
        if !isPriority && isRateLimited() {
            return
        }

        queue.async { [weak self] in
            self?.buffer.append(entry)
        }
    }

    var isConnected: Bool { transport.isConnected }

    // MARK: - Collector Support

    private func register(_ collector: LogCollector) {
        collector.onLog = { [weak self] entry in
            self?.ingest(entry)
        }
        collector.start()
        collectors.append(collector)
    }

    /// Synchronously drains the buffer and persists all pending logs.
    /// Called by CrashCollector during fatal signal/exception handling.
    /// Uses persistence for reliability since viewers may not be connected during a crash.
    func emergencyFlush() {
        let batch = buffer.drain()
        if !batch.isEmpty {
            transport.emergencyPersist(batch)
            // Also try sending over transport in case a viewer is connected
            transport.send(batch)
        }
    }

    // MARK: - Rate Limiting

    /// Returns true if the current log should be dropped due to rate limiting.
    private func isRateLimited() -> Bool {
        let maxPerSecond = configuration.limits.maxLogsPerSecond
        guard maxPerSecond > 0 else { return false } // 0 = unlimited

        rateLimitLock.lock(); defer { rateLimitLock.unlock() }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastSecondTimestamp)

        if elapsed >= 1.0 {
            // Reset counter for new second window
            lastSecondTimestamp = now
            logCountThisSecond = 1
            return false
        }

        logCountThisSecond += 1
        return logCountThisSecond > maxPerSecond
    }

    // MARK: - Memory Warning Response

    private func observeMemoryWarnings() {
        #if canImport(UIKit) && !os(watchOS)
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        #endif
    }

    private func removeMemoryWarningObserver() {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
            memoryWarningObserver = nil
        }
    }

    private func handleMemoryWarning() {
        // Immediately flush the buffer
        let batch = buffer.drain()
        if !batch.isEmpty {
            transport.send(batch)
        }

        // Reduce max buffer count by 50%
        let currentMax = buffer.maxSize
        let reducedMax = max(currentMax / 2, 50) // don't go below 50
        buffer.reduceMaxSize(to: reducedMax)

        print("[ProbySDK] Memory warning: flushed buffer, reduced maxSize to \(reducedMax)")
    }

    /// Check estimated memory and aggressively flush if over hard cap.
    /// Called periodically or on demand.
    func checkMemoryPressure() {
        let estimatedUsage = buffer.maxSize * estimatedEntrySize
        if estimatedUsage > memoryHardCapBytes {
            let batch = buffer.drain()
            if !batch.isEmpty {
                transport.send(batch)
            }
            let targetMax = memoryHardCapBytes / estimatedEntrySize
            buffer.reduceMaxSize(to: max(targetMax, 50))
            print("[ProbySDK] Memory hard cap exceeded: aggressively reduced buffer to \(targetMax)")
        }
    }
}
