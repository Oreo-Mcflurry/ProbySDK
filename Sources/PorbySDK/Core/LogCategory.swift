import Foundation

/// Extensible category struct. Users extend via `extension PorbyCategory { static let ... }`
public struct PorbyCategory: Hashable, Codable, Sendable, ExpressibleByStringLiteral {
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
public extension PorbyCategory {
    static let app         = PorbyCategory("app", emoji: "📱")
    static let network     = PorbyCategory("network", emoji: "🌐")
    static let crash       = PorbyCategory("crash", emoji: "💥")
    static let ui          = PorbyCategory("ui", emoji: "🎨")
    static let bluetooth   = PorbyCategory("bluetooth", emoji: "📡")
    static let lifecycle   = PorbyCategory("lifecycle", emoji: "🔄")
    static let performance = PorbyCategory("performance", emoji: "📊")
}
