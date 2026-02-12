import Foundation

/// A single frame in a stack trace
public struct StackFrame: Codable, Sendable, Hashable {
    public let index: UInt32
    public let symbol: String
    public let module: String
    public let file: String?
    public let line: UInt32?
    public let address: String

    public init(
        index: UInt32,
        symbol: String,
        module: String,
        file: String? = nil,
        line: UInt32? = nil,
        address: String
    ) {
        self.index = index
        self.symbol = symbol
        self.module = module
        self.file = file
        self.line = line
        self.address = address
    }
}

/// Structured data for crash logs
public struct CrashLogData: Codable, Sendable, Hashable {
    public let signal: String?
    public let exceptionType: String?
    public let exceptionReason: String?
    public let stackTrace: [StackFrame]
    public let threadName: String?

    public init(
        signal: String? = nil,
        exceptionType: String? = nil,
        exceptionReason: String? = nil,
        stackTrace: [StackFrame] = [],
        threadName: String? = nil
    ) {
        self.signal = signal
        self.exceptionType = exceptionType
        self.exceptionReason = exceptionReason
        self.stackTrace = stackTrace
        self.threadName = threadName
    }
}
