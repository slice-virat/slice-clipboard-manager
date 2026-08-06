import Foundation

/// Reads and writes the history file.
///
/// A file that fails to decode is renamed aside rather than deleted — losing
/// user data silently is worse than leaving a stray file behind.
public struct HistoryPersistence: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `~/Library/Application Support/ClipboardManager`, created if absent.
    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ClipboardManager", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Never throws. A missing file yields an empty list; a corrupt one is
    /// quarantined first.
    public func load() -> [ClipEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entries = try? decoder.decode([ClipEntry].self, from: data) else {
            quarantine()
            return []
        }
        return entries
    }

    public func save(_ entries: [ClipEntry]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(entries)
        // Atomic so an interrupted write cannot truncate the existing file.
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: fileURL.path)
    }

    /// Destination used when the live file cannot be decoded.
    public var quarantinedURL: URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return fileURL.deletingLastPathComponent()
            .appendingPathComponent("\(fileURL.lastPathComponent).corrupt-\(stamp)")
    }

    private func quarantine() {
        try? FileManager.default.moveItem(at: fileURL, to: quarantinedURL)
    }
}
