import AppKit

/// Watches the system pasteboard for new text.
///
/// macOS publishes no clipboard-change notification, so polling `changeCount` is
/// the only mechanism available. 0.3s is imperceptible and costs nothing
/// measurable — `changeCount` is a cheap integer read.
@MainActor
final class ClipboardMonitor {
    /// Marker set by password managers on sensitive copies.
    static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    private let pollInterval: TimeInterval
    private let onNewText: (String) -> Void
    private let pasteboard: NSPasteboard
    // No `deinit` invalidates this: the scheduled closure captures `[weak self]`,
    // so a pending timer never retains the `ClipboardMonitor`. If the monitor is
    // deallocated with polling active, the run loop keeps that one timer alive
    // until it fires, `self` is nil, and it simply no-ops. Do not add a
    // `deinit` that calls `timer?.invalidate()` — `Timer.invalidate()` must be
    // called from the thread that installed the timer, which `deinit` cannot
    // guarantee.
    private var timer: Timer?
    private var lastChangeCount: Int
    private var suppressUntilChangeCount: Int?

    /// When true, copies marked concealed are ignored. Off by default.
    var filterSecrets: Bool

    init(pollInterval: TimeInterval = 0.3,
         filterSecrets: Bool,
         pasteboard: NSPasteboard = .general,
         onNewText: @escaping (String) -> Void) {
        self.pollInterval = pollInterval
        self.filterSecrets = filterSecrets
        self.pasteboard = pasteboard
        self.onNewText = onNewText
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call immediately before writing to the pasteboard ourselves, so the
    /// resulting change is not re-recorded as a new copy.
    func suppressNextChange() {
        suppressUntilChangeCount = pasteboard.changeCount + 1
    }

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        if let suppressed = suppressUntilChangeCount, suppressed == current {
            suppressUntilChangeCount = nil
            return
        }
        suppressUntilChangeCount = nil

        if filterSecrets, let types = pasteboard.types, types.contains(Self.concealedType) {
            return
        }
        guard let text = pasteboard.string(forType: .string) else { return }
        onNewText(text)
    }
}
