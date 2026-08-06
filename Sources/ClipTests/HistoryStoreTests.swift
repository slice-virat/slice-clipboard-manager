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
