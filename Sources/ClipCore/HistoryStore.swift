import Foundation

/// Most-recently-used-ordered clipboard history, capped at `maxEntries`.
///
/// Index 0 is always the most recent entry. Both a fresh copy of existing text
/// and an explicit `promote` funnel through the same move-to-front primitive, so
/// re-copying and re-pasting produce identical ordering.
@MainActor
public final class HistoryStore {
    public private(set) var entries: [ClipEntry] = []
    public let maxEntries: Int

    /// Called after any mutation that changed `entries`.
    public var onChange: (() -> Void)?

    public init(maxEntries: Int = 50, entries: [ClipEntry] = []) {
        self.maxEntries = max(1, maxEntries)
        self.entries = Array(entries.prefix(self.maxEntries))
    }

    /// Records newly copied text. Returns false when the text was ignored.
    @discardableResult
    public func insert(_ text: String, now: Date = Date()) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        if let existing = entries.firstIndex(where: { $0.text == text }) {
            var entry = entries.remove(at: existing)
            entry.createdAt = now
            entries.insert(entry, at: 0)
        } else {
            entries.insert(ClipEntry(text: text, createdAt: now), at: 0)
            if entries.count > maxEntries {
                entries.removeLast(entries.count - maxEntries)
            }
        }
        onChange?()
        return true
    }
}
