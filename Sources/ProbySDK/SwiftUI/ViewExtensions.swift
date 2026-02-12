#if canImport(SwiftUI)
import SwiftUI

public extension View {
    /// Automatically logs onAppear/onDisappear for this view
    func probyLogView(_ name: String, category: ProbyCategory = .ui) -> some View {
        self.onAppear {
            Proby.info("\(name) appeared", category: category)
        }
        .onDisappear {
            Proby.info("\(name) disappeared", category: category)
        }
    }
}

/// Logs function calls
public enum LogAction {
    public static func track(
        _ label: String,
        category: ProbyCategory = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        Proby.debug("\(label) called", category: category, file: file, function: function, line: line)
    }
}
#endif
