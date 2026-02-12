import Foundation

/// Metadata value supporting common primitive types
public enum ProbyMetadataValue: Sendable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}

extension ProbyMetadataValue: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v):    try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v):   try container.encode(v)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        throw DecodingError.typeMismatch(
            ProbyMetadataValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported metadata value type")
        )
    }
}

extension ProbyMetadataValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension ProbyMetadataValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension ProbyMetadataValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension ProbyMetadataValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

/// Convenience typealias for metadata dictionaries
public typealias ProbyMetadata = [String: ProbyMetadataValue]

/// Extra structured data attached to a log entry
public enum ProbyLogExtra: Codable, Sendable {
    case network(NetworkLogData)
    case crash(CrashLogData)
    case ui(UILogData)
    case performance(PerformanceData)
}

/// A single log entry captured by the SDK
public struct ProbyLogEntry: Codable, Sendable, Identifiable {
    public let id: String
    public let timestamp: Date
    public let level: ProbyLogLevel
    public let category: ProbyCategory
    public let message: String
    public let file: String
    public let function: String
    public let line: UInt
    public let metadata: ProbyMetadata?
    public let extra: ProbyLogExtra?

    /// OpenTelemetry severity number derived from level
    public var severityNumber: Int {
        level.severityNumber
    }

    public init(
        id: String = UUID().uuidString,
        timestamp: Date = Date(),
        level: ProbyLogLevel,
        category: ProbyCategory,
        message: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        metadata: ProbyMetadata? = nil,
        extra: ProbyLogExtra? = nil
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
