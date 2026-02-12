import Logging

public struct ProbyLogHandler: LogHandler {
    public var metadata: Logger.Metadata = [:]
    public var logLevel: Logger.Level = .trace

    private let category: ProbyCategory

    public init(category: ProbyCategory = .app) {
        self.category = category
    }

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let probyLevel = Self.mapLevel(level)
        var probyMeta: ProbyMetadata? = nil

        let merged = self.metadata.merging(metadata ?? [:]) { _, new in new }
        if !merged.isEmpty {
            var dict: [String: ProbyMetadataValue] = [:]
            for (key, value) in merged {
                dict[key] = .string("\(value)")
            }
            if !source.isEmpty {
                dict["_source"] = .string(source)
            }
            probyMeta = dict
        }

        Proby.forward(
            level: probyLevel,
            category: category,
            message: "\(message)",
            metadata: probyMeta,
            source: source,
            file: file,
            function: function,
            line: line
        )
    }

    public static func mapLevel(_ level: Logger.Level) -> ProbyLogLevel {
        switch level {
        case .trace:    return .verbose
        case .debug:    return .debug
        case .info:     return .info
        case .notice:   return .info
        case .warning:  return .warning
        case .error:    return .error
        case .critical: return .fatal
        }
    }
}

// Bootstrap helper on Proby facade
public extension Proby {
    /// SwiftLog bootstrap factory. Usage: `LoggingSystem.bootstrap(Proby.swiftLogHandler)`
    static func swiftLogHandler(label: String) -> ProbyLogHandler {
        ProbyLogHandler(category: ProbyCategory(label, emoji: nil))
    }
}
