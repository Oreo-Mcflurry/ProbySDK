#if canImport(SwiftUI)
import SwiftUI

public extension View {
    /// Automatically logs onAppear/onDisappear for this view
    func porbyLogView(_ name: String, category: PorbyCategory = .ui) -> some View {
        self.onAppear {
            Porby.info("\(name) appeared", category: category)
        }
        .onDisappear {
            Porby.info("\(name) disappeared", category: category)
        }
    }
}

/// Logs function calls
public enum LogAction {
    public static func track(
        _ label: String,
        category: PorbyCategory = .app,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        Porby.debug("\(label) called", category: category, file: file, function: function, line: line)
    }
}
#endif
