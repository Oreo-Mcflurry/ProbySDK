import Foundation

final class MessageCodec: @unchecked Sendable {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func encode<T: Encodable>(_ value: T) -> Data? {
        try? encoder.encode(value)
    }

    func decode<T: Decodable>(_ data: Data) -> T? {
        try? decoder.decode(T.self, from: data)
    }
}
