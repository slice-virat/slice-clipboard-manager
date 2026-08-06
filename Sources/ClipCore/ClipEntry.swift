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

    /// Single-line, whitespace-collapsed rendering for display in the panel.
    public var preview: String {
        let collapsed = text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
        if collapsed.count <= Self.previewLength { return collapsed }
        let cut = collapsed.prefix(Self.previewLength - 1)
        return cut + "…"
    }
}
