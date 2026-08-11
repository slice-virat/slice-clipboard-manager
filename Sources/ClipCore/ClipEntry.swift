import Foundation

/// One captured clipboard text snippet.
public struct ClipEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public var createdAt: Date

    public init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }

    /// Maximum characters shown in a panel row, including the ellipsis.
    public static let previewLength = 80

    /// The text with every run of whitespace collapsed to a single space, at full
    /// length. This is what searching matches against.
    ///
    /// Matching the raw `text` instead would make the panel lie: a row displays
    /// `preview`, which is collapsed, so a phrase that *reads* as contiguous there
    /// may be split by a newline in the original and fail to match.
    public var searchText: String {
        text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
    }

    /// Single-line, whitespace-collapsed rendering for display in the panel.
    public var preview: String {
        let collapsed = searchText
        if collapsed.count <= Self.previewLength { return collapsed }
        let cut = collapsed.prefix(Self.previewLength - 1)
        return cut + "…"
    }

    /// True when every whitespace-separated term in `query` appears somewhere in
    /// the entry, in any order. Case- and diacritic-insensitive.
    ///
    /// Terms are matched independently rather than as one contiguous phrase,
    /// because that is what a search box is expected to do: typing `invoice 2026`
    /// should find "2026 invoice draft", not just the exact sequence.
    ///
    /// An empty or whitespace-only query matches everything.
    public func matches(_ query: String) -> Bool {
        let terms = query.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        guard !terms.isEmpty else { return true }
        let haystack = searchText
        return terms.allSatisfy { term in
            haystack.range(of: String(term),
                           options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
