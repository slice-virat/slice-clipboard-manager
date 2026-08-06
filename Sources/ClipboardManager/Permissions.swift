import AppKit
import ApplicationServices

/// Accessibility permission, required only for synthesising ⌘V.
@MainActor
enum Permissions {
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Checks permission and, if absent, asks macOS to show its grant prompt.
    @discardableResult
    static func requestAccessibility() -> Bool {
        // `kAXTrustedCheckOptionPrompt` is imported from C as a mutable
        // global, which Swift 6 strict concurrency flags on every reference
        // regardless of the caller's own isolation or any `nonisolated`
        // annotation applied at the call site — the diagnostic is tied to the
        // SDK's own declaration, not to how we bind it. Its value is the
        // stable, publicly documented string "AXTrustedCheckOptionPrompt";
        // using the literal removes the unsafe global reference entirely
        // instead of annotating around it.
        let key = "AXTrustedCheckOptionPrompt"
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
