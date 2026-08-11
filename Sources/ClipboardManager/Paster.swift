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

        guard let target else {
            return .copiedOnly(reason: "No target application was recorded.")
        }

        // Restore focus BEFORE checking Accessibility, and unconditionally.
        // Activating another application needs no special permission — only
        // synthesising the keystroke does. Checking the permission first meant
        // that without it we returned early and never reactivated anything, so
        // the user was left staring at a dismissed panel with their previous
        // window still unfocused, having to click it before they could paste.
        // Copy-only mode should still put them back where they came from.
        let activated = target.activate()
        let targetName = target.localizedName ?? "the previous app"

        guard Permissions.isAccessibilityGranted else {
            return .copiedOnly(reason: activated
                ? "Accessibility permission is not granted — press ⌘V to paste."
                : "Accessibility permission is not granted, and \(targetName) could not be reactivated.")
        }
        guard activated else {
            return .copiedOnly(reason: "Could not activate \(targetName).")
        }

        // Built synchronously so a construction failure can still be
        // reported through the return value. Only the *posting* of these
        // already-built events is delayed, never their construction.
        let source = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        else {
            return .copiedOnly(reason: "Could not construct the paste keystroke.")
        }
        down.flags = .maskCommand
        up.flags = .maskCommand

        DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay) {
            MainActor.assumeIsolated { postCommandV(down: down, up: up) }
        }
        return .pasted
    }

    private static func postCommandV(down: CGEvent, up: CGEvent) {
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
