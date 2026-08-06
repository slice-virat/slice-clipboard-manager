import AppKit
import ClipCore

/// Wires every component together and owns application lifetime.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var config = Config.default
    private var store = HistoryStore()
    private var persistence = HistoryPersistence(fileURL: HistoryPersistence.defaultDirectory
        .appendingPathComponent("history.json"))
    private let saveDebouncer = Debouncer(delay: 0.5)

    private var monitor: ClipboardMonitor?
    private var hotkey: HotkeyManager?
    private var panel: PanelController?
    private var menuBar: MenuBarController?

    private var configURL: URL {
        HistoryPersistence.defaultDirectory.appendingPathComponent("config.json")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        config = Config.load(from: configURL)
        // Write the file back so it exists and is discoverable for hand-editing.
        try? config.save(to: configURL)

        store = HistoryStore(maxEntries: config.maxEntries)
        store.replaceAll(persistence.load())
        store.onChange = { [weak self] in self?.scheduleSave() }

        let monitor = ClipboardMonitor(filterSecrets: config.filterSecrets) { [weak self] text in
            self?.store.insert(text)
        }
        monitor.start()
        self.monitor = monitor

        let panel = PanelController(store: store) { [weak self] entry, target in
            self?.paste(entry, into: target)
        }
        self.panel = panel

        menuBar = MenuBarController(
            onShowPanel: { [weak self] in self?.panel?.show() },
            onClearHistory: { [weak self] in
                self?.store.clear()
                self?.saveDebouncer.flush()
            },
            onToggleLaunchAtLogin: { [weak self] in
                guard let self else { return }
                if let error = LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled) {
                    self.menuBar?.setWarning("Launch at login failed: \(error)")
                }
            }
        )

        let hotkey = HotkeyManager(config: config.hotkey) { [weak self] in
            self?.panel?.toggle()
        }
        do {
            try hotkey.register()
        } catch {
            menuBar?.setWarning(error.localizedDescription)
        }
        self.hotkey = hotkey

        if config.launchAtLogin {
            LaunchAtLogin.setEnabled(true)
        }

        if !Permissions.isAccessibilityGranted {
            promptForAccessibility()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Flush rather than lose the last few seconds of history.
        saveDebouncer.flush()
        hotkey?.unregister()
        monitor?.stop()
    }

    private func scheduleSave() {
        saveDebouncer.schedule { [weak self] in
            guard let self else { return }
            do {
                try self.persistence.save(self.store.entries)
            } catch {
                self.menuBar?.setWarning("Could not save history: \(error.localizedDescription)")
            }
        }
    }

    private func paste(_ entry: ClipEntry, into target: NSRunningApplication?) {
        store.promote(entry.id)
        let outcome = Paster.deliver(text: entry.text, to: target, monitor: monitor)
        switch outcome {
        case .pasted:
            menuBar?.setWarning(nil)
        case .copiedOnly(let reason):
            menuBar?.setWarning("Copied to clipboard only — \(reason)")
        }
    }

    private func promptForAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Clipboard Manager needs Accessibility access"
        alert.informativeText = """
            To paste directly into the app you were using, Clipboard Manager needs \
            permission to send keystrokes. Without it, choosing an entry still copies \
            it to the clipboard — you just press ⌘V yourself.
            """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            Permissions.requestAccessibility()
            Permissions.openAccessibilitySettings()
        }
    }
}
