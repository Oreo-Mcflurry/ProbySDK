import Foundation

/// Captures uncaught NSExceptions and Unix signals, emitting crash log entries.
///
/// On crash, performs an emergency flush via `LogEngine.shared.emergencyFlush()`
/// to attempt delivering buffered logs before the process terminates.
final class CrashCollector: LogCollector {
    var onLog: ((PorbyLogEntry) -> Void)?

    /// Shared reference so C signal handler and exception handler can reach the callback
    private static weak var shared: CrashCollector?

    /// Previous exception handler to restore on stop
    private var previousExceptionHandler: (@convention(c) (NSException) -> Void)?

    /// Tracked signals and their previous actions
    private static let caughtSignals: [Int32] = [SIGABRT, SIGBUS, SIGFPE, SIGILL, SIGSEGV, SIGTRAP]
    private var previousSignalActions: [Int32: sigaction] = [:]

    func start() {
        CrashCollector.shared = self
        installExceptionHandler()
        installSignalHandlers()
    }

    func stop() {
        restoreExceptionHandler()
        restoreSignalHandlers()
        CrashCollector.shared = nil
    }

    // MARK: - NSException Handler

    private func installExceptionHandler() {
        previousExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            CrashCollector.handleException(exception)
        }
    }

    private func restoreExceptionHandler() {
        NSSetUncaughtExceptionHandler(previousExceptionHandler)
        previousExceptionHandler = nil
    }

    private static func handleException(_ exception: NSException) {
        let frames = captureStackFrames(exception.callStackSymbols)

        let crashData = CrashLogData(
            signal: nil,
            exceptionType: exception.name.rawValue,
            exceptionReason: exception.reason,
            stackTrace: frames,
            threadName: Thread.current.name
        )

        let entry = PorbyLogEntry(
            level: .fatal,
            category: .crash,
            message: "Uncaught exception: \(exception.name.rawValue) — \(exception.reason ?? "no reason")",
            file: "CrashCollector",
            function: "exception",
            line: 0,
            extra: .crash(crashData)
        )

        shared?.onLog?(entry)

        // Emergency flush — try to deliver buffered logs before dying
        LogEngine.shared.emergencyFlush()
    }

    // MARK: - Signal Handlers

    private func installSignalHandlers() {
        for sig in Self.caughtSignals {
            var oldAction = sigaction()
            var newAction = sigaction()
            newAction.__sigaction_u.__sa_handler = CrashCollector.signalHandler
            sigemptyset(&newAction.sa_mask)
            newAction.sa_flags = 0
            sigaction(sig, &newAction, &oldAction)
            previousSignalActions[sig] = oldAction
        }
    }

    private func restoreSignalHandlers() {
        for sig in Self.caughtSignals {
            if var oldAction = previousSignalActions[sig] {
                sigaction(sig, &oldAction, nil)
            }
        }
        previousSignalActions.removeAll()
    }

    private static let signalHandler: @convention(c) (Int32) -> Void = { signal in
        let signalName = CrashCollector.signalName(signal)

        // Capture current call stack
        let symbols = Thread.callStackSymbols
        let frames = captureStackFrames(symbols)

        let crashData = CrashLogData(
            signal: signalName,
            exceptionType: "Signal",
            exceptionReason: "Received signal \(signalName) (\(signal))",
            stackTrace: frames,
            threadName: Thread.current.name
        )

        let entry = PorbyLogEntry(
            level: .fatal,
            category: .crash,
            message: "Fatal signal: \(signalName)",
            file: "CrashCollector",
            function: "signal",
            line: 0,
            extra: .crash(crashData)
        )

        shared?.onLog?(entry)

        // Emergency flush
        LogEngine.shared.emergencyFlush()

        // Re-raise the signal with the default handler so the OS generates a crash report
        Foundation.signal(signal, SIG_DFL)
        raise(signal)
    }

    // MARK: - Helpers

    private static func signalName(_ sig: Int32) -> String {
        switch sig {
        case SIGABRT: return "SIGABRT"
        case SIGBUS:  return "SIGBUS"
        case SIGFPE:  return "SIGFPE"
        case SIGILL:  return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGTRAP: return "SIGTRAP"
        default:      return "SIG\(sig)"
        }
    }

    /// Parse callStackSymbols into structured StackFrame array
    private static func captureStackFrames(_ symbols: [String]) -> [StackFrame] {
        return symbols.enumerated().compactMap { index, symbol in
            // Format: "index  module  address  symbol + offset"
            let parts = symbol.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count >= 4 else {
                return StackFrame(
                    index: UInt32(index),
                    symbol: symbol.trimmingCharacters(in: .whitespaces),
                    module: "unknown",
                    address: "0x0"
                )
            }
            return StackFrame(
                index: UInt32(index),
                symbol: String(parts[3]),
                module: String(parts[1]),
                address: String(parts[2])
            )
        }
    }
}
