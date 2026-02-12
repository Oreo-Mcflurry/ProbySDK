import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects app lifecycle events via NotificationCenter and emits log entries.
final class LifecycleCollector: LogCollector {
    var onLog: ((ProbyLogEntry) -> Void)?

    #if canImport(UIKit)
    private var observers: [NSObjectProtocol] = []
    #endif

    func start() {
        #if canImport(UIKit)
        let events: [(Notification.Name, String, ProbyLogLevel)] = [
            (UIApplication.didFinishLaunchingNotification,    "App did finish launching",     .info),
            (UIApplication.willResignActiveNotification,      "App will resign active",       .info),
            (UIApplication.didEnterBackgroundNotification,    "App did enter background",     .info),
            (UIApplication.willEnterForegroundNotification,   "App will enter foreground",    .info),
            (UIApplication.didBecomeActiveNotification,       "App did become active",        .info),
            (UIApplication.willTerminateNotification,         "App will terminate",           .info),
            (UIApplication.didReceiveMemoryWarningNotification, "Memory warning received",    .warning),
        ]

        for (name, message, level) in events {
            let observer = NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.emit(message: message, level: level)
            }
            observers.append(observer)
        }
        #endif
    }

    func stop() {
        #if canImport(UIKit)
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        #endif
    }

    private func emit(message: String, level: ProbyLogLevel) {
        let entry = ProbyLogEntry(
            level: level,
            category: .lifecycle,
            message: message,
            file: "LifecycleCollector",
            function: "lifecycle",
            line: 0
        )
        onLog?(entry)
    }
}
