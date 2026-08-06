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

    private func rebuildMenu() {
        let menu = NSMenu()

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

        statusItem.menu = menu
    }

    @objc private func showPanel() { onShowPanel() }
    @objc private func clearHistory() { onClearHistory() }

    @objc private func toggleLaunchAtLogin() {
        onToggleLaunchAtLogin()
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
