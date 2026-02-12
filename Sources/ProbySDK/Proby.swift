import Foundation

/// Public facade for the Proby remote logging SDK
public enum Proby {

    // MARK: - Lifecycle

    public static func start() {
        LogEngine.shared.start(configuration: .default)
    }

    public static func start(_ configure: (inout ProbyConfiguration) -> Void) {
        var config = ProbyConfiguration()
        configure(&config)
        LogEngine.shared.start(configuration: config)
    }

    public static func start(configuration: ProbyConfiguration) {
        LogEngine.shared.start(configuration: configuration)
    }

    public static func stop() {
        LogEngine.shared.stop()
    }

    // MARK: - Logging (core API)

    public static func log(
        _ category: ProbyCategory,
        _ level: ProbyLogLevel,
        _ message: @autoclosure () -> String,
        metadata: ProbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        guard LogEngine.shared.shouldLog(level: level, category: category) else { return }
        let entry = ProbyLogEntry(
            level: level,
            category: category,
            message: message(),
            file: file,
            function: function,
            line: line,
            metadata: metadata
        )
        LogEngine.shared.ingest(entry)
    }

    // MARK: - Convenience Level Methods

    public static func verbose(
        _ message: @autoclosure () -> String,
        category: ProbyCategory = .app,
        metadata: ProbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        log(category, .verbose, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public static func debug(
        _ message: @autoclosure () -> String,
        category: ProbyCategory = .app,
        metadata: ProbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        log(category, .debug, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public static func info(
        _ message: @autoclosure () -> String,
        category: ProbyCategory = .app,
        metadata: ProbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        log(category, .info, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public static func warning(
        _ message: @autoclosure () -> String,
        category: ProbyCategory = .app,
        metadata: ProbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        log(category, .warning, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public static func error(
        _ message: @autoclosure () -> String,
        category: ProbyCategory = .app,
        metadata: ProbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        log(category, .error, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public static func fatal(
        _ message: @autoclosure () -> String,
        category: ProbyCategory = .app,
        metadata: ProbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        log(category, .fatal, message(), metadata: metadata, file: file, function: function, line: line)
    }

    // MARK: - Scoped Logger

    public static func logger(for category: ProbyCategory) -> ProbyCategoryLogger {
        ProbyCategoryLogger(category: category)
    }

    // MARK: - Measurement

    @discardableResult
    public static func measure<T>(
        _ label: String,
        category: ProbyCategory = .performance,
        _ block: () throws -> T
    ) rethrows -> T {
        log(category, .info, "\(label) started")
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        log(category, .info, String(format: "%@ completed (%.1fms)", label, duration))
        return result
    }

    @discardableResult
    public static func measure<T>(
        _ label: String,
        category: ProbyCategory = .performance,
        _ block: () async throws -> T
    ) async rethrows -> T {
        log(category, .info, "\(label) started")
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        log(category, .info, String(format: "%@ completed (%.1fms)", label, duration))
        return result
    }

    // MARK: - External Integration Bridge

    /// Bridge API for external logging systems (SwiftLog, OSLog, etc.) to inject logs
    public static func forward(
        level: ProbyLogLevel,
        category: ProbyCategory = .app,
        message: String,
        metadata: ProbyMetadata? = nil,
        source: String? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        guard LogEngine.shared.shouldLog(level: level, category: category) else { return }
        var fullMeta = metadata ?? [:]
        if let source = source {
            fullMeta["_source"] = .string(source)
        }
        let entry = ProbyLogEntry(
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line,
            metadata: fullMeta.isEmpty ? nil : fullMeta
        )
        LogEngine.shared.ingest(entry)
    }

    // MARK: - Connection State

    public static var isConnected: Bool { LogEngine.shared.isConnected }

    public static func onConnectionChanged(_ handler: @escaping (ConnectionState) -> Void) {
        LogEngine.shared.onConnectionChanged = handler
    }
}
