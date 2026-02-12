import Foundation

// MARK: - NetworkCollector

/// Intercepts HTTP network traffic via URLProtocol and emits structured network logs.
final class NetworkCollector: LogCollector {
    var onLog: ((PorbyLogEntry) -> Void)?

    func start() {
        PorbyURLProtocol.onLogCallback = { [weak self] entry in
            self?.onLog?(entry)
        }
        URLProtocol.registerClass(PorbyURLProtocol.self)
    }

    func stop() {
        URLProtocol.unregisterClass(PorbyURLProtocol.self)
        PorbyURLProtocol.onLogCallback = nil
    }
}

// MARK: - PorbyURLProtocol

/// Custom URLProtocol that intercepts URL requests for logging purposes.
/// Uses a "PorbyHandled" flag to prevent infinite recursion.
final class PorbyURLProtocol: URLProtocol {

    // MARK: - Static callback

    /// Static callback used by NetworkCollector to receive log entries.
    /// Must be static because URLProtocol instances are created by the system.
    static var onLogCallback: ((PorbyLogEntry) -> Void)?

    // MARK: - Constants

    private static let handledKey = "PorbyHandled"

    // MARK: - Instance state

    private var dataTask: URLSessionDataTask?
    private var receivedData = Data()
    private var response: URLResponse?
    private var startTime: Date?

    // MARK: - URLProtocol overrides

    override class func canInit(with request: URLRequest) -> Bool {
        // Skip if already handled (prevent infinite loop)
        guard URLProtocol.property(forKey: handledKey, in: request) == nil else {
            return false
        }
        // Only intercept HTTP/HTTPS
        guard let scheme = request.url?.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // Mark request as handled to prevent re-interception
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)

        startTime = Date()
        receivedData = Data()

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        dataTask = session.dataTask(with: mutableRequest as URLRequest)
        dataTask?.resume()
    }

    override func stopLoading() {
        dataTask?.cancel()
        dataTask = nil
    }

    // MARK: - Log emission

    private func emitLog(for request: URLRequest, response: URLResponse?, data: Data, error: Error?) {
        let privacy = LogEngine.shared.configuration.privacy

        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "unknown"
        let redactor = Redactor(config: privacy)
        let redactedURL = redactor.redactURL(url)

        // Request headers (redacted)
        let reqHeaders: [String: String]? = request.allHTTPHeaderFields.map { redactor.redactHeaders($0) }

        // Request body (truncated)
        let maxBody = privacy.maxBodySize
        let reqBody: String? = {
            guard maxBody > 0, let body = request.httpBody, !body.isEmpty else { return nil }
            let truncated = body.prefix(maxBody)
            return String(data: truncated, encoding: .utf8)
        }()

        // Response data
        var statusCode: UInt16?
        var respHeaders: [String: String]?
        if let httpResponse = response as? HTTPURLResponse {
            statusCode = UInt16(httpResponse.statusCode)
            let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, pair in
                if let key = pair.key as? String, let value = pair.value as? String {
                    result[key] = value
                }
            }
            respHeaders = redactor.redactHeaders(headers)
        }

        // Response body (truncated)
        let respBody: String? = {
            guard maxBody > 0, !data.isEmpty else { return nil }
            let truncated = data.prefix(maxBody)
            return String(data: truncated, encoding: .utf8)
        }()

        // Duration
        let durationMs: Double? = startTime.map { Date().timeIntervalSince($0) * 1000 }

        // Determine log level from status code
        let level: PorbyLogLevel = {
            guard let code = statusCode else {
                return error != nil ? .error : .info
            }
            switch code {
            case 200..<300: return .info
            case 300..<500: return .warning
            default:        return .error   // 5xx and anything else
            }
        }()

        // Build message
        let message: String = {
            if let code = statusCode {
                return "\(method) \(redactedURL) → \(code)"
            } else if let error = error {
                return "\(method) \(redactedURL) → Error: \(error.localizedDescription)"
            } else {
                return "\(method) \(redactedURL)"
            }
        }()

        let networkData = NetworkLogData(
            method: method,
            url: redactedURL,
            statusCode: statusCode,
            requestHeaders: reqHeaders,
            responseHeaders: respHeaders,
            requestBody: reqBody,
            responseBody: respBody,
            durationMs: durationMs,
            byteSent: request.httpBody.map { UInt64($0.count) },
            byteReceived: UInt64(data.count)
        )

        let entry = PorbyLogEntry(
            level: level,
            category: .network,
            message: message,
            file: "NetworkCollector",
            function: "intercept",
            line: 0,
            extra: .network(networkData)
        )

        Self.onLogCallback?(entry)
    }
}

// MARK: - URLSessionDataDelegate

extension PorbyURLProtocol: URLSessionDataDelegate {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        client?.urlProtocol(self, didLoad: data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
        emitLog(for: request, response: response, data: receivedData, error: error)
        session.invalidateAndCancel()
    }
}
