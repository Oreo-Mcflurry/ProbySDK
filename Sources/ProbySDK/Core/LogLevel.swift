import Foundation

/// Log severity level (6 levels, fixed)
public enum ProbyLogLevel: Int, Comparable, CaseIterable, Sendable {
    case verbose = 0
    case debug   = 1
    case info    = 2
    case warning = 3
    case error   = 4
    case fatal   = 5

    public static func < (lhs: ProbyLogLevel, rhs: ProbyLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var emoji: String {
        switch self {
        case .verbose: return "⚪"
        case .debug:   return "🔵"
        case .info:    return "🟢"
        case .warning: return "🟡"
        case .error:   return "🔴"
        case .fatal:   return "💀"
        }
    }

    /// OpenTelemetry SeverityNumber (1-24 range)
    public var severityNumber: Int {
        switch self {
        case .verbose: return 1
        case .debug:   return 5
        case .info:    return 9
        case .warning: return 13
        case .error:   return 17
        case .fatal:   return 21
        }
    }
}

extension ProbyLogLevel: Codable {
    private var stringValue: String {
        switch self {
        case .verbose: return "verbose"
        case .debug:   return "debug"
        case .info:    return "info"
        case .warning: return "warning"
        case .error:   return "error"
        case .fatal:   return "fatal"
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        switch string {
        case "verbose": self = .verbose
        case "debug":   self = .debug
        case "info":    self = .info
        case "warning": self = .warning
        case "error":   self = .error
        case "fatal":   self = .fatal
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown log level: \(string)"
            )
        }
    }
}
