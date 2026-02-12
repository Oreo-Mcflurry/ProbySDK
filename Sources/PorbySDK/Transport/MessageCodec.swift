import Foundation

/// JSON-based message codec for WebSocket communication (Phase 1 MVP)
final class MessageCodec: @unchecked Sendable {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func encode<T: Encodable>(_ value: T) -> Data? {
        try? encoder.encode(value)
    }

    func decode<T: Decodable>(_ data: Data) -> T? {
        try? decoder.decode(T.self, from: data)
    }
}
