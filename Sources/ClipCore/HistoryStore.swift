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
            moveToFront(at: existing, now: now)
        } else {
            entries.insert(ClipEntry(text: text, createdAt: now), at: 0)
            if entries.count > maxEntries {
                entries.removeLast(entries.count - maxEntries)
            }
        }
        onChange?()
        return true
    }

    /// Moves an existing entry to the front. Returns false if the id is unknown.
    @discardableResult
    public func promote(_ id: UUID, now: Date = Date()) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        moveToFront(at: index, now: now)
        onChange?()
        return true
    }

    /// Case- and diacritic-insensitive substring match, preserving list order.
    /// An empty or whitespace-only query returns every entry.
    public func filter(_ query: String) -> [ClipEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter {
            $0.text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// Replaces the entire list, e.g. when loading from disk. Does not fire `onChange`.
    public func replaceAll(_ newEntries: [ClipEntry]) {
        entries = Array(newEntries.prefix(maxEntries))
    }

    public func clear() {
        entries.removeAll()
        onChange?()
    }

    /// Removes the entry at `index`, refreshes its `createdAt`, and reinserts it at the front.
    /// Shared by `insert`'s dedupe branch and `promote` so both produce identical ordering.
    private func moveToFront(at index: Int, now: Date) {
        var entry = entries.remove(at: index)
        entry.createdAt = now
        entries.insert(entry, at: 0)
    }
}
