import Foundation

/// WebSocket message types exchanged between SDK (server) and Desktop viewer (client)
public enum WsMessage: Sendable {
    case handshake(Handshake)
    case log(ProbyLogEntry)
    case logBatch([ProbyLogEntry])
    case logReplay([ProbyLogEntry])
    case ping
    case pong
    case command(ViewerCommand)
    case pairingRequest(code: String)
    case pairingResponse(accepted: Bool, reason: String?)
}

// MARK: - Codable

extension WsMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, payload
    }

    private enum MessageType: String, Codable {
        case handshake, log, logBatch, logReplay
        case ping, pong
        case command
        case pairingRequest, pairingResponse
    }

    // Helpers for pairingResponse
    private struct PairingResponsePayload: Codable {
        let accepted: Bool
        let reason: String?
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .handshake(let value):
            try container.encode(MessageType.handshake, forKey: .type)
            try container.encode(value, forKey: .payload)
        case .log(let entry):
            try container.encode(MessageType.log, forKey: .type)
            try container.encode(entry, forKey: .payload)
        case .logBatch(let entries):
            try container.encode(MessageType.logBatch, forKey: .type)
            try container.encode(entries, forKey: .payload)
        case .logReplay(let entries):
            try container.encode(MessageType.logReplay, forKey: .type)
            try container.encode(entries, forKey: .payload)
        case .ping:
            try container.encode(MessageType.ping, forKey: .type)
        case .pong:
            try container.encode(MessageType.pong, forKey: .type)
        case .command(let cmd):
            try container.encode(MessageType.command, forKey: .type)
            try container.encode(cmd, forKey: .payload)
        case .pairingRequest(let code):
            try container.encode(MessageType.pairingRequest, forKey: .type)
            try container.encode(code, forKey: .payload)
        case .pairingResponse(let accepted, let reason):
            try container.encode(MessageType.pairingResponse, forKey: .type)
            try container.encode(PairingResponsePayload(accepted: accepted, reason: reason), forKey: .payload)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .handshake:
            self = .handshake(try container.decode(Handshake.self, forKey: .payload))
        case .log:
            self = .log(try container.decode(ProbyLogEntry.self, forKey: .payload))
        case .logBatch:
            self = .logBatch(try container.decode([ProbyLogEntry].self, forKey: .payload))
        case .logReplay:
            self = .logReplay(try container.decode([ProbyLogEntry].self, forKey: .payload))
        case .ping:
            self = .ping
        case .pong:
            self = .pong
        case .command:
            self = .command(try container.decode(ViewerCommand.self, forKey: .payload))
        case .pairingRequest:
            self = .pairingRequest(code: try container.decode(String.self, forKey: .payload))
        case .pairingResponse:
            let payload = try container.decode(PairingResponsePayload.self, forKey: .payload)
            self = .pairingResponse(accepted: payload.accepted, reason: payload.reason)
        }
    }
}

/// Commands sent from Desktop viewer to iOS SDK
public enum ViewerCommand: Sendable {
    case setLogLevel(ProbyLogLevel)
    case setCategoryLevel(category: ProbyCategory, level: ProbyLogLevel)
    case setEnabled(enabled: Bool, category: ProbyCategory)
    case clearLogs
    case requestPerformanceSnapshot
}

// MARK: - ViewerCommand Codable

extension ViewerCommand: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, level, category, enabled
    }

    private enum CommandType: String, Codable {
        case setLogLevel, setCategoryLevel, setEnabled, clearLogs, requestPerformanceSnapshot
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .setLogLevel(let level):
            try container.encode(CommandType.setLogLevel, forKey: .type)
            try container.encode(level, forKey: .level)
        case .setCategoryLevel(let category, let level):
            try container.encode(CommandType.setCategoryLevel, forKey: .type)
            try container.encode(category, forKey: .category)
            try container.encode(level, forKey: .level)
        case .setEnabled(let enabled, let category):
            try container.encode(CommandType.setEnabled, forKey: .type)
            try container.encode(enabled, forKey: .enabled)
            try container.encode(category, forKey: .category)
        case .clearLogs:
            try container.encode(CommandType.clearLogs, forKey: .type)
        case .requestPerformanceSnapshot:
            try container.encode(CommandType.requestPerformanceSnapshot, forKey: .type)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(CommandType.self, forKey: .type)

        switch type {
        case .setLogLevel:
            self = .setLogLevel(try container.decode(ProbyLogLevel.self, forKey: .level))
        case .setCategoryLevel:
            let category = try container.decode(ProbyCategory.self, forKey: .category)
            let level = try container.decode(ProbyLogLevel.self, forKey: .level)
            self = .setCategoryLevel(category: category, level: level)
        case .setEnabled:
            let enabled = try container.decode(Bool.self, forKey: .enabled)
            let category = try container.decode(ProbyCategory.self, forKey: .category)
            self = .setEnabled(enabled: enabled, category: category)
        case .clearLogs:
            self = .clearLogs
        case .requestPerformanceSnapshot:
            self = .requestPerformanceSnapshot
        }
    }
}
