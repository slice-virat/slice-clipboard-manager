import AppKit
import SwiftUI
import ClipCore

/// Owns the floating panel and the focus hand-off around it.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let store: HistoryStore
    private let onPaste: (ClipEntry, NSRunningApplication?) -> Void
    private var panel: NSPanel?
    private var previousApp: NSRunningApplication?

    init(store: HistoryStore,
         onPaste: @escaping (ClipEntry, NSRunningApplication?) -> Void) {
        self.store = store
        self.onPaste = onPaste
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        if isVisible { hide() } else { show() }
    }

    func show() {
        // Record the target before we steal focus.
        previousApp = NSWorkspace.shared.frontmostApplication

        let panel = makePanel()
        self.panel = panel
        panel.center(on: screenUnderMouse())
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func makePanel() -> NSPanel {
        let view = ClipPanelView(
            entries: store.entries,
            onChoose: { [weak self] entry in
                guard let self else { return }
                let target = self.previousApp
                self.hide()
                self.onPaste(entry, target)
            },
            onDismiss: { [weak self] in self?.hide() }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.contentView = NSHostingView(rootView: view)
        panel.delegate = self
        return panel
    }

    private func screenUnderMouse() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    /// Dismiss when focus moves elsewhere — clicking outside counts.
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}

private extension NSPanel {
    func center(on screen: NSScreen) {
        let visible = screen.visibleFrame
        let size = frame.size
        setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.1
        ))
    }
}
