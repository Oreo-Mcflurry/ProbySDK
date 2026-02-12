import Foundation

/// Log severity level (6 levels, fixed)
public enum PorbyLogLevel: Int, Codable, Comparable, CaseIterable, Sendable {
    case verbose = 0
    case debug   = 1
    case info    = 2
    case warning = 3
    case error   = 4
    case fatal   = 5

    public static func < (lhs: PorbyLogLevel, rhs: PorbyLogLevel) -> Bool {
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
