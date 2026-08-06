import Foundation

/// Coalesces rapid calls into a single deferred execution.
///
/// Used so a burst of copies produces one disk write rather than one per copy.
@MainActor
public final class Debouncer {
    private let delay: TimeInterval
    // `nonisolated(unsafe)` so `deinit` (always nonisolated) can invalidate the
    // timer on deallocation. Safe because `Timer.invalidate()` is documented
    // as callable from any thread.
    private nonisolated(unsafe) var timer: Timer?
    private var pending: (() -> Void)?

    public init(delay: TimeInterval) {
        self.delay = delay
    }

    /// Replaces any pending work and restarts the delay.
    public func schedule(_ block: @escaping () -> Void) {
        pending = block
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
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

    deinit {
        timer?.invalidate()
    }
}
