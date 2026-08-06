import Foundation

/// Coalesces rapid calls into a single deferred execution.
///
/// Used so a burst of copies produces one disk write rather than one per copy.
@MainActor
public final class Debouncer {
    private let delay: TimeInterval
    // No `deinit` invalidates this: the scheduled closure captures `[weak self]`,
    // so a pending timer never retains the `Debouncer`. If the debouncer is
    // deallocated with work pending, the run loop keeps that one timer alive
    // until it fires, `self` is nil, and it simply no-ops. Do not add a
    // `deinit` that calls `timer?.invalidate()` — `Timer.invalidate()` must be
    // called from the thread that installed the timer, which `deinit` cannot
    // guarantee.
    private var timer: Timer?
    private var pending: (() -> Void)?

    public init(delay: TimeInterval) {
        self.delay = delay
    }

    /// Replaces any pending work and restarts the delay.
    public func schedule(_ block: @escaping () -> Void) {
        pending = block
        timer?.invalidate()
        // `Timer.scheduledTimer` only registers on the `.default` run loop mode,
        // which AppKit stops servicing while a menu is tracking or a modal alert
        // is up (`.eventTracking` / `.modalPanel`). Schedule explicitly on
        // `.common` so a pending save isn't stalled for as long as those last.
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Runs pending work immediately, if any. Safe to call when nothing is pending.
    public func flush() {
        timer?.invalidate()
        timer = nil
        let block = pending
        pending = nil
        block?()
    }

    public func cancel() {
        timer?.invalidate()
        timer = nil
        pending = nil
    }
}
