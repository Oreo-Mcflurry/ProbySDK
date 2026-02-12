import Foundation

/// Protocol that all auto-collectors must conform to.
/// Each collector observes a specific system aspect and emits log entries via `onLog`.
protocol LogCollector: AnyObject {
    /// Callback set by LogEngine to receive collected log entries
    var onLog: ((PorbyLogEntry) -> Void)? { get set }

    /// Begin collecting events
    func start()

    /// Stop collecting events and clean up resources
    func stop()
}
