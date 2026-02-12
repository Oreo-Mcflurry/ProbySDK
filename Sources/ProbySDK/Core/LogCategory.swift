import Foundation

/// Extensible category struct. Users extend via `extension ProbyCategory { static let ... }`
public struct ProbyCategory: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let identifier: String
    public let emoji: String?

    public init(_ identifier: String, emoji: String? = nil) {
        self.identifier = identifier
        self.emoji = emoji
    }

    public init(stringLiteral value: String) {
        self.identifier = value
        self.emoji = nil
    }
}

// MARK: - Built-in Categories
public extension ProbyCategory {
    static let app         = ProbyCategory("app", emoji: "📱")
    static let network     = ProbyCategory("network", emoji: "🌐")
    static let crash       = ProbyCategory("crash", emoji: "💥")
    static let ui          = ProbyCategory("ui", emoji: "🎨")
    static let bluetooth   = ProbyCategory("bluetooth", emoji: "📡")
    static let lifecycle   = ProbyCategory("lifecycle", emoji: "🔄")
    static let performance = ProbyCategory("performance", emoji: "📊")
}
