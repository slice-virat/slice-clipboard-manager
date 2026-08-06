import AppKit
import Carbon.HIToolbox

/// Puts text on the pasteboard and, when permitted, synthesises ⌘V into the
/// app that was frontmost before the panel opened.
@MainActor
enum Paster {
    enum Outcome: Equatable {
        case pasted
        /// Text reached the clipboard but ⌘V could not be sent.
        case copiedOnly(reason: String)
    }

    /// Delay allowing the target app's activation to land before keystrokes are
    /// posted. Below roughly 50ms the keystroke can arrive while our panel is
    /// still key and get swallowed.
    static let activationDelay: TimeInterval = 0.08

    @discardableResult
    static func deliver(text: String,
                        to target: NSRunningApplication?,
                        monitor: ClipboardMonitor?) -> Outcome {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // AFTER the write, so an unrelated write cannot consume the suppression.
        monitor?.noteSelfWrite()

        guard Permissions.isAccessibilityGranted else {
            return .copiedOnly(reason: "Accessibility permission is not granted.")
        }
        guard let target else {
            return .copiedOnly(reason: "No target application was recorded.")
        }
        guard target.activate() else {
            return .copiedOnly(reason: "Could not activate \(target.localizedName ?? "the app").")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay) {
            MainActor.assumeIsolated { sendCommandV() }
        }
        return .pasted
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
