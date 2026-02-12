import Foundation

/// Metadata value supporting common primitive types
public enum PorbyMetadataValue: Codable, Sendable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}

extension PorbyMetadataValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension PorbyMetadataValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension PorbyMetadataValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension PorbyMetadataValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

/// Convenience typealias for metadata dictionaries
public typealias PorbyMetadata = [String: PorbyMetadataValue]

/// Extra structured data attached to a log entry
public enum PorbyLogExtra: Codable, Sendable {
    case network(NetworkLogData)
    case crash(CrashLogData)
    case ui(UILogData)
    case performance(PerformanceData)
}

/// A single log entry captured by the SDK
public struct PorbyLogEntry: Codable, Sendable, Identifiable {
    public let id: String
    public let timestamp: Date
    public let level: PorbyLogLevel
    public let category: PorbyCategory
    public let message: String
    public let file: String
    public let function: String
    public let line: UInt
    public let metadata: PorbyMetadata?
    public let extra: PorbyLogExtra?

    /// OpenTelemetry severity number derived from level
    public var severityNumber: Int {
        level.severityNumber
    }

    public init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        level: PorbyLogLevel,
        category: PorbyCategory,
        message: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        metadata: PorbyMetadata? = nil,
        extra: PorbyLogExtra? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.file = file
        self.function = function
        self.line = line
        self.metadata = metadata
        self.extra = extra
    }
}
