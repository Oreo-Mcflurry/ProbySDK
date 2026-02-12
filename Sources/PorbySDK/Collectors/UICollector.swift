import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Collects UI screen transitions by swizzling UIViewController.viewDidAppear.
final class UICollector: LogCollector {
    var onLog: ((PorbyLogEntry) -> Void)?

    /// Shared reference so the swizzled method can reach the callback
    static weak var shared: UICollector?

    #if canImport(UIKit)
    private static var hasSwizzled = false
    #endif

    func start() {
        #if canImport(UIKit)
        UICollector.shared = self
        swizzleViewDidAppearIfNeeded()
        #endif
    }

    func stop() {
        #if canImport(UIKit)
        UICollector.shared = nil
        // Note: we do NOT un-swizzle. The swizzled method checks `shared == nil`
        // and becomes a no-op. Re-swizzling would be unsafe.
        #endif
    }

    #if canImport(UIKit)
    private func swizzleViewDidAppearIfNeeded() {
        guard !UICollector.hasSwizzled else { return }
        UICollector.hasSwizzled = true

        let originalSelector = #selector(UIViewController.viewDidAppear(_:))
        let swizzledSelector = #selector(UIViewController.porby_viewDidAppear(_:))

        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector)
        else { return }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    #endif

    // MARK: - Filtering

    /// Returns true for system/internal VCs that should not be logged
    static func isSystemViewController(_ name: String) -> Bool {
        let prefixes = ["UI", "_", "NSObject"]
        let exactNames = [
            "UINavigationController",
            "UITabBarController",
            "UIPageViewController",
            "UIInputWindowController",
            "UICompatibilityInputViewController",
            "UISystemInputAssistantViewController",
            "UIEditingOverlayViewController",
            "UIPredictionViewController",
        ]

        if exactNames.contains(name) { return true }
        for prefix in prefixes where name.hasPrefix(prefix) { return true }
        return false
    }
}

// MARK: - UIViewController Swizzle Extension

#if canImport(UIKit)
extension UIViewController {
    @objc func porby_viewDidAppear(_ animated: Bool) {
        // Call original (swizzled) implementation
        porby_viewDidAppear(animated)

        let name = String(describing: type(of: self))

        // Filter out system VCs
        guard !UICollector.isSystemViewController(name) else { return }

        // Check if collector is still active
        guard let collector = UICollector.shared else { return }

        let uiData = UILogData(
            eventType: .viewAppear,
            viewName: name
        )

        let entry = PorbyLogEntry(
            level: .info,
            category: .ui,
            message: "Screen appeared: \(name)",
            file: "UICollector",
            function: "viewDidAppear",
            line: 0,
            extra: .ui(uiData)
        )

        collector.onLog?(entry)
    }
}
#endif
