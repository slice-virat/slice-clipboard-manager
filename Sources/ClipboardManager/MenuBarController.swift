import AppKit

/// The status-bar icon and its menu. Also the surface for warnings, so a failed
/// hotkey registration, login-item change, disk save, or paste degradation is
/// visible rather than silent.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    /// One warning slot per independent failure domain, so an event in one
    /// domain (e.g. a successful paste) can never clobber or mask an
    /// unrelated, still-unresolved warning in another (e.g. a dead hotkey).
    enum WarningKind: Hashable {
        case hotkey
        case launchAtLogin
        case persistence
        case paste
    }

    /// Fixed so the menu lists warnings in a stable, predictable order.
    private static let warningOrder: [WarningKind] = [.hotkey, .launchAtLogin, .persistence, .paste]

    private let statusItem: NSStatusItem
    /// A single, long-lived `NSMenu` instance, mutated in place by
    /// `rebuildMenu()` rather than replaced. AppKit already holds a reference
    /// to whichever menu object is currently tracking a click when it invokes
    /// `menuWillOpen`; swapping `statusItem.menu` to a *new* object from
    /// inside that callback would not affect the menu already on screen, so
    /// the "Enable Auto-Paste…" item could still go stale until the next
    /// open-close cycle. Rebuilding this same instance's items is the
    /// documented, supported way to keep a menu's contents current at the
    /// moment it opens.
    private let menu = NSMenu()
    private let onShowPanel: () -> Void
    private let onClearHistory: () -> Void
    private let onToggleLaunchAtLogin: () -> Void

    private var warnings: [WarningKind: String] = [:]

    init(onShowPanel: @escaping () -> Void,
         onClearHistory: @escaping () -> Void,
         onToggleLaunchAtLogin: @escaping () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.onShowPanel = onShowPanel
        self.onClearHistory = onClearHistory
        self.onToggleLaunchAtLogin = onToggleLaunchAtLogin
        super.init()

        statusItem.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "Clipboard Manager")
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()
    }

    /// Surfaces a problem on the icon and in the menu, scoped to `kind` so it
    /// cannot be cleared by an unrelated event resolving. Pass `nil` to clear
    /// just that domain's warning; other domains are untouched.
    func setWarning(_ message: String?, for kind: WarningKind) {
        if let message {
            warnings[kind] = message
        } else {
            warnings.removeValue(forKey: kind)
        }
        let symbol = warnings.isEmpty ? "doc.on.clipboard" : "exclamationmark.triangle"
        statusItem.button?.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: "Clipboard Manager")
        rebuildMenu()
    }

    /// Repopulates `menu`'s items from scratch. Always mutates the same
    /// `NSMenu` instance held in `menu` — never creates or assigns a new one
    /// — so this is also safe to call from `menuWillOpen`, i.e. while `menu`
    /// is the very menu currently being displayed.
    private func rebuildMenu() {
        menu.removeAllItems()

        let activeMessages = Self.warningOrder.compactMap { warnings[$0] }
        if !activeMessages.isEmpty {
            for message in activeMessages {
                let item = NSMenuItem(title: message, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        menu.addItem(withTitle: "Show Clipboard History",
                     action: #selector(showPanel), keyEquivalent: "").target = self

        // Only offered while the permission is missing. This is the way back in
        // for someone who was not an administrator on first launch — the startup
        // alert fires at most once, so without this the request is unreachable.
        if !Permissions.isAccessibilityGranted {
            menu.addItem(withTitle: "Enable Auto-Paste…",
                         action: #selector(requestAccessibility), keyEquivalent: "").target = self
        }

        let launchItem = NSMenuItem(title: "Launch at Login",
                                    action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear History",
                     action: #selector(clearHistory), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Clipboard Manager",
                     action: #selector(quit), keyEquivalent: "q").target = self
    }

    /// Sent by AppKit right before this menu is displayed. Rebuilding here
    /// re-evaluates `Permissions.isAccessibilityGranted`, so "Enable
    /// Auto-Paste…" is correct at the one moment it actually matters — when
    /// the user is looking at the menu — rather than only after some
    /// unrelated event (a warning change, a login-item toggle) happens to
    /// trigger a rebuild first.
    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc private func showPanel() { onShowPanel() }
    @objc private func clearHistory() { onClearHistory() }

    @objc private func toggleLaunchAtLogin() {
        onToggleLaunchAtLogin()
        rebuildMenu()
    }

    @objc private func requestAccessibility() {
        Permissions.requestAccessibility()
        Permissions.openAccessibilitySettings()
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
