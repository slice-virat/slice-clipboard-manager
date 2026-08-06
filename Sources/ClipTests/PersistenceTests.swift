import Foundation
import ClipCore

@MainActor
func runPersistenceTests() {
    Harness.suite("HistoryPersistence")

    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("cliptests-history-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("history.json")
    let store = HistoryPersistence(fileURL: url)

    Harness.expectEqual(store.load().isEmpty, true, "missing file loads as empty")

    let t0 = Date(timeIntervalSince1970: 3_000)
    let entries = [
        ClipEntry(text: "first", createdAt: t0),
        ClipEntry(text: "second", createdAt: t0.addingTimeInterval(1)),
    ]
    try? store.save(entries)
    Harness.expectEqual(store.load(), entries, "entries round-trip through disk unchanged")

    // Regression: an .iso8601 date strategy has no fractional seconds and
    // would silently truncate this, breaking Equatable equality after reload.
    let subSecond = ClipEntry(text: "sub-second", createdAt: Date(timeIntervalSince1970: 3_000.123456))
    try? store.save([subSecond])
    Harness.expectEqual(store.load(), [subSecond], "sub-second timestamp precision survives a round-trip")

    // File must not be world- or group-readable.
    let mode = (try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber)??.intValue
    Harness.expectEqual(mode, 0o600, "history file is written with mode 0600")

    // Corrupt file: quarantine, do not delete, and load empty.
    try? Data("{ this is not valid json".utf8).write(to: url)
    Harness.expectEqual(store.load().isEmpty, true, "corrupt file loads as empty")
    let quarantined = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?
        .filter { $0.hasPrefix("history.json.corrupt-") } ?? []
    Harness.expectEqual(quarantined.count, 1, "corrupt file is quarantined, not deleted")
    Harness.expectEqual(FileManager.default.fileExists(atPath: url.path), false,
                        "corrupt file is moved aside from the live path")

    Harness.suite("Debouncer")

    var calls = 0
    let debouncer = Debouncer(delay: 60)
    debouncer.schedule { calls += 1 }
    debouncer.schedule { calls += 1 }
    Harness.expectEqual(calls, 0, "scheduled work does not run immediately")
    debouncer.flush()
    Harness.expectEqual(calls, 1, "flush runs the latest pending work exactly once")
    debouncer.flush()
    Harness.expectEqual(calls, 1, "flush with nothing pending does nothing")

    debouncer.schedule { calls += 1 }
    debouncer.cancel()
    debouncer.flush()
    Harness.expectEqual(calls, 1, "cancel discards pending work")
}
