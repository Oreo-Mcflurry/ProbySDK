import Foundation

/// Public facade for the Porby remote logging SDK
public enum Porby {

    // MARK: - Lifecycle

    public static func start() {
        LogEngine.shared.start(configuration: .default)
    }

    public static func start(_ configure: (inout PorbyConfiguration) -> Void) {
        var config = PorbyConfiguration()
        configure(&config)
        LogEngine.shared.start(configuration: config)
    }

    public static func start(configuration: PorbyConfiguration) {
        LogEngine.shared.start(configuration: configuration)
    }

    public static func stop() {
        LogEngine.shared.stop()
    }

    // MARK: - Logging (core API)

    public static func log(
        _ category: PorbyCategory,
        _ level: PorbyLogLevel,
        _ message: @autoclosure () -> String,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        guard LogEngine.shared.shouldLog(level: level, category: category) else { return }
        let entry = PorbyLogEntry(
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
        category: PorbyCategory = .app,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        log(category, .verbose, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public static func debug(
        _ message: @autoclosure () -> String,
        category: PorbyCategory = .app,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        log(category, .debug, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public static func info(
        _ message: @autoclosure () -> String,
        category: PorbyCategory = .app,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        log(category, .info, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public static func warning(
        _ message: @autoclosure () -> String,
        category: PorbyCategory = .app,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        log(category, .warning, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public static func error(
        _ message: @autoclosure () -> String,
        category: PorbyCategory = .app,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        log(category, .error, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public static func fatal(
        _ message: @autoclosure () -> String,
        category: PorbyCategory = .app,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        log(category, .fatal, message(), metadata: metadata, file: file, function: function, line: line)
    }

    // MARK: - Scoped Logger

    public static func logger(for category: PorbyCategory) -> PorbyCategoryLogger {
        PorbyCategoryLogger(category: category)
    }

    // MARK: - Measurement

    @discardableResult
    public static func measure<T>(
        _ label: String,
        category: PorbyCategory = .performance,
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
        category: PorbyCategory = .performance,
        _ block: () async throws -> T
    ) async rethrows -> T {
        log(category, .info, "\(label) started")
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
        log(category, .info, String(format: "%@ completed (%.1fms)", label, duration))
        return result
    }

    // MARK: - Connection State

    public static var isConnected: Bool { LogEngine.shared.isConnected }

    public static func onConnectionChanged(_ handler: @escaping (ConnectionState) -> Void) {
        LogEngine.shared.onConnectionChanged = handler
    }
}
