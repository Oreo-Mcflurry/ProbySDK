import Foundation

/// Utility that sanitizes headers, metadata, and query parameters based on privacy config
struct Redactor {
    let config: PorbyConfiguration.Privacy

    func redactHeaders(_ headers: [String: String]) -> [String: String] {
        var result = headers
        for key in headers.keys {
            if config.redactedHeaderNames.contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
                result[key] = config.redactionPlaceholder
            }
        }
        return result
    }

    func redactMetadata(_ metadata: PorbyMetadata) -> PorbyMetadata {
        var result = metadata
        for key in metadata.keys {
            if config.redactedMetadataKeys.contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
                result[key] = .string(config.redactionPlaceholder)
            }
        }
        return result
    }

    func redactURL(_ urlString: String) -> String {
        guard var components = URLComponents(string: urlString) else { return urlString }
        components.queryItems = components.queryItems?.map { item in
            if config.redactedQueryParams.contains(item.name.lowercased()) {
                return URLQueryItem(name: item.name, value: config.redactionPlaceholder)
            }
            return item
        }
        return components.url?.absoluteString ?? urlString
    }
}
