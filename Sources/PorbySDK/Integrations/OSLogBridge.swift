import Foundation
import os.log

public extension Porby {
    /// Mirror a log to Apple's unified logging system (os_log)
    @available(iOS 14.0, macOS 11.0, watchOS 7.0, *)
    static func osLog(
        _ level: PorbyLogLevel,
        category: PorbyCategory = .app,
        message: String
    ) {
        let logger = os.Logger(
            subsystem: LogEngine.shared.configuration.resolvedAppName,
            category: category.identifier
        )
        switch level {
        case .verbose, .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        case .fatal:
            logger.fault("\(message, privacy: .public)")
        }
    }
}
