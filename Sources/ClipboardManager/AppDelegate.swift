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
        // The menu bar does not exist yet at this point, so any failure is
        // captured here and surfaced once it does, a few lines down.
        var configSaveError: String?
        do {
            try config.save(to: configURL)
        } catch {
            configSaveError = "Could not save config: \(error.localizedDescription)"
        }

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
                self.applyLaunchAtLogin(!LaunchAtLogin.isEnabled)
            }
        )

        // Surfaced only now that the menu bar exists to surface it on.
        if let configSaveError {
            menuBar?.setWarning(configSaveError, for: .persistence)
        }

        let hotkey = HotkeyManager(config: config.hotkey) { [weak self] in
            self?.panel?.toggle()
        }
        do {
            try hotkey.register()
        } catch {
            menuBar?.setWarning(error.localizedDescription, for: .hotkey)
        }
        self.hotkey = hotkey

        if config.launchAtLogin {
            applyLaunchAtLogin(true)
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

    /// Registers or unregisters the login item and reports the outcome under
    /// the `.launchAtLogin` warning domain — clearing it on success, setting
    /// it on failure — so a stale failure is never left displayed once the
    /// condition resolves, and this domain is never touched by an unrelated
    /// success (e.g. a paste) elsewhere.
    private func applyLaunchAtLogin(_ enabled: Bool) {
        let error = LaunchAtLogin.setEnabled(enabled)
        menuBar?.setWarning(error.map { "Launch at login failed: \($0)" }, for: .launchAtLogin)
    }

    private func scheduleSave() {
        saveDebouncer.schedule { [weak self] in
            guard let self else { return }
            do {
                try self.persistence.save(self.store.entries)
                self.menuBar?.setWarning(nil, for: .persistence)
            } catch {
                self.menuBar?.setWarning("Could not save history: \(error.localizedDescription)", for: .persistence)
            }
        }
    }

    private func paste(_ entry: ClipEntry, into target: NSRunningApplication?) {
        store.promote(entry.id)
        let outcome = Paster.deliver(text: entry.text, to: target, monitor: monitor)
        switch outcome {
        case .pasted:
            menuBar?.setWarning(nil, for: .paste)
        case .copiedOnly(let reason):
            menuBar?.setWarning("Copied to clipboard only — \(reason)", for: .paste)
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
