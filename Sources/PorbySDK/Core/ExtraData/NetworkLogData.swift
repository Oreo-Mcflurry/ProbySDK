import Foundation

/// Structured data for network request/response logs
public struct NetworkLogData: Codable, Sendable, Hashable {
    public let method: String
    public let url: String
    public let statusCode: UInt16?
    public let requestHeaders: [String: String]?
    public let responseHeaders: [String: String]?
    public let requestBody: String?
    public let responseBody: String?
    public let durationMs: Double?
    public let byteSent: UInt64?
    public let byteReceived: UInt64?

    public init(
        method: String,
        url: String,
        statusCode: UInt16? = nil,
        requestHeaders: [String: String]? = nil,
        responseHeaders: [String: String]? = nil,
        requestBody: String? = nil,
        responseBody: String? = nil,
        durationMs: Double? = nil,
        byteSent: UInt64? = nil,
        byteReceived: UInt64? = nil
    ) {
        self.method = method
        self.url = url
        self.statusCode = statusCode
        self.requestHeaders = requestHeaders
        self.responseHeaders = responseHeaders
        self.requestBody = requestBody
        self.responseBody = responseBody
        self.durationMs = durationMs
        self.byteSent = byteSent
        self.byteReceived = byteReceived
    }
}
