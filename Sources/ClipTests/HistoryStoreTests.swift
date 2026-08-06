import Foundation
import ClipCore

@MainActor
func runHistoryStoreTests() {
    Harness.suite("ClipEntry")

    let entry = ClipEntry(text: "hello")
    Harness.expectEqual(entry.text, "hello", "stores text verbatim")

    let messy = ClipEntry(text: "  line one\n\n\tline two   ")
    Harness.expectEqual(messy.preview, "line one line two", "preview collapses whitespace and trims")

    let long = ClipEntry(text: String(repeating: "a", count: 200))
    Harness.expectEqual(long.preview.count, 80, "preview truncates to 80 characters")
    Harness.expect(long.preview.hasSuffix("…"), "truncated preview ends with an ellipsis")
}

@MainActor
func runHistoryInsertTests() {
    Harness.suite("HistoryStore.insert")

    let t0 = Date(timeIntervalSince1970: 1_000)

    let store = HistoryStore(maxEntries: 3)
    store.insert("one", now: t0)
    store.insert("two", now: t0.addingTimeInterval(1))
    Harness.expectEqual(store.entries.map(\.text), ["two", "one"], "newest entry is first")

    Harness.expectEqual(store.insert("", now: t0), false, "empty text is rejected")
    Harness.expectEqual(store.insert("   \n\t ", now: t0), false, "whitespace-only text is rejected")
    Harness.expectEqual(store.entries.count, 2, "rejected inserts do not change the list")

    // Re-inserting existing text promotes rather than duplicates.
    let promotedAt = t0.addingTimeInterval(10)
    store.insert("one", now: promotedAt)
    Harness.expectEqual(store.entries.map(\.text), ["one", "two"], "duplicate insert promotes to front")
    Harness.expectEqual(store.entries.count, 2, "duplicate insert does not grow the list")
    Harness.expectEqual(store.entries[0].createdAt, promotedAt, "promoted entry refreshes createdAt")

    // Cap evicts exactly the oldest.
    let capped = HistoryStore(maxEntries: 3)
    for (i, text) in ["a", "b", "c", "d"].enumerated() {
        capped.insert(text, now: t0.addingTimeInterval(Double(i)))
    }
    Harness.expectEqual(capped.entries.map(\.text), ["d", "c", "b"], "cap evicts the oldest entry")
    Harness.expectEqual(capped.entries.count, 3, "cap holds the list at maxEntries")

    // onChange fires for accepted inserts only.
    var changes = 0
    let observed = HistoryStore(maxEntries: 3)
    observed.onChange = { changes += 1 }
    observed.insert("x", now: t0)
    observed.insert("", now: t0)
    Harness.expectEqual(changes, 1, "onChange fires only for accepted inserts")
}

@MainActor
func runHistoryPromoteAndFilterTests() {
    Harness.suite("HistoryStore.promote / filter")

    let t0 = Date(timeIntervalSince1970: 2_000)
    let store = HistoryStore(maxEntries: 10)
    for (i, text) in ["alpha", "beta", "gamma", "delta"].enumerated() {
        store.insert(text, now: t0.addingTimeInterval(Double(i)))
    }
    // entries are now delta, gamma, beta, alpha
    let beta = store.entries.first { $0.text == "beta" }!

    let later = t0.addingTimeInterval(50)
    Harness.expectEqual(store.promote(beta.id, now: later), true, "promote returns true for a known id")
    Harness.expectEqual(store.entries.map(\.text), ["beta", "delta", "gamma", "alpha"],
                        "promote moves the entry to front and preserves the rest of the order")
    Harness.expectEqual(store.entries[0].createdAt, later, "promote refreshes createdAt")
    Harness.expectEqual(store.promote(UUID(), now: later), false, "promote of an unknown id is a no-op")
    Harness.expectEqual(store.entries.count, 4, "no-op promote does not change the list")

    Harness.expectEqual(store.filter("").map(\.text), store.entries.map(\.text),
                        "empty query returns everything in order")
    Harness.expectEqual(store.filter("   ").count, 4, "whitespace-only query returns everything")
    Harness.expectEqual(store.filter("ALPHA").map(\.text), ["alpha"], "filter is case-insensitive")
    Harness.expectEqual(store.filter("mm").map(\.text), ["gamma"], "filter matches a substring")
    Harness.expectEqual(store.filter("zzz").isEmpty, true, "no match yields an empty list")

    let accented = HistoryStore(maxEntries: 5)
    accented.insert("café", now: t0)
    Harness.expectEqual(accented.filter("cafe").count, 1, "filter is diacritic-insensitive")

    store.replaceAll([ClipEntry(text: "only", createdAt: t0)])
    Harness.expectEqual(store.entries.map(\.text), ["only"], "replaceAll swaps the whole list")

    store.clear()
    Harness.expectEqual(store.entries.isEmpty, true, "clear empties the list")
}
