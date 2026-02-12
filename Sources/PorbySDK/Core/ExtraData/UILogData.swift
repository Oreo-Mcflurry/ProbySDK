import Foundation

/// Types of UI events that can be logged
public enum UIEventType: String, Codable, Sendable {
    case viewAppear
    case viewDisappear
    case buttonTap
    case navigation
    case alert
}

/// Structured data for UI event logs
public struct UILogData: Codable, Sendable, Hashable {
    public let eventType: UIEventType
    public let viewName: String
    public let detail: String?

    public init(
        eventType: UIEventType,
        viewName: String,
        detail: String? = nil
    ) {
        self.eventType = eventType
        self.viewName = viewName
        self.detail = detail
    }
}
