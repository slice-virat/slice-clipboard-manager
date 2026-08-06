import AppKit
@preconcurrency import ApplicationServices

/// Accessibility permission, required only for synthesising ⌘V.
@MainActor
enum Permissions {
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Checks permission and, if absent, asks macOS to show its grant prompt.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
