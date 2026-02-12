import Foundation
import MessagePack

/// MessagePack-based codec for efficient binary serialization
final class MessageCodec: @unchecked Sendable {
    private let encoder = MessagePackEncoder()
    private let decoder = MessagePackDecoder()

    func encode<T: Encodable>(_ value: T) -> Data? {
        try? encoder.encode(value)
    }

    func decode<T: Decodable>(_ data: Data) -> T? {
        try? decoder.decode(T.self, from: data)
    }
}
