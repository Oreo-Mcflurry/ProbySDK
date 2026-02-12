import Foundation

/// Scoped logger bound to a specific category
public struct PorbyCategoryLogger {
    public let category: PorbyCategory

    public func verbose(
        _ message: @autoclosure () -> String,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        Porby.log(category, .verbose, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public func debug(
        _ message: @autoclosure () -> String,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        Porby.log(category, .debug, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public func info(
        _ message: @autoclosure () -> String,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        Porby.log(category, .info, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public func warning(
        _ message: @autoclosure () -> String,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        Porby.log(category, .warning, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public func error(
        _ message: @autoclosure () -> String,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        Porby.log(category, .error, message(), metadata: metadata, file: file, function: function, line: line)
    }

    public func fatal(
        _ message: @autoclosure () -> String,
        metadata: PorbyMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        Porby.log(category, .fatal, message(), metadata: metadata, file: file, function: function, line: line)
    }
}
