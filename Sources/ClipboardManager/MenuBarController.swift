import AppKit

/// The status-bar icon and its menu. Also the surface for warnings, so a failed
/// hotkey registration is visible rather than silent.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let onShowPanel: () -> Void
    private let onClearHistory: () -> Void
    private let onToggleLaunchAtLogin: () -> Void

    private var warning: String?

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

    /// Surfaces a problem on the icon and in the menu. Pass nil to clear.
    func setWarning(_ message: String?) {
        warning = message
        let symbol = message == nil ? "doc.on.clipboard" : "exclamationmark.triangle"
        statusItem.button?.image = NSImage(
            systemSymbolName: symbol,
            accessibilityDescription: "Clipboard Manager")
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if let warning {
            let item = NSMenuItem(title: warning, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
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
