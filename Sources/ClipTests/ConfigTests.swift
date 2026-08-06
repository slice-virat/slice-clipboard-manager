import Foundation
import ClipCore

@MainActor
func runConfigTests() {
    Harness.suite("Config")

    let d = Config.default
    Harness.expectEqual(d.maxEntries, 50, "default maxEntries is 50")
    Harness.expectEqual(d.filterSecrets, false, "secret filtering is off by default")
    Harness.expectEqual(d.launchAtLogin, true, "launch at login is on by default")
    Harness.expectEqual(d.hotkey.keyCode, 9, "default hotkey keyCode is 9 (V)")
    Harness.expectEqual(d.hotkey.modifiers, ["control", "option"], "default modifiers are control+option")

    // controlKey (4096) | optionKey (2048) == 6144
    Harness.expectEqual(d.hotkey.carbonModifiers, 6144, "control+option maps to Carbon 6144")
    Harness.expectEqual(
        HotkeyConfig(keyCode: 9, modifiers: ["command", "shift"]).carbonModifiers, 768,
        "command+shift maps to Carbon 768")
    Harness.expectEqual(
        HotkeyConfig(keyCode: 9, modifiers: ["bogus"]).carbonModifiers, 0,
        "unknown modifier names are ignored")

    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("cliptests-config-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let url = dir.appendingPathComponent("config.json")

    Harness.expectEqual(Config.load(from: url), Config.default, "missing file yields defaults")

    // Partial config: unspecified keys fall back to defaults.
    try? Data(#"{"maxEntries": 7}"#.utf8).write(to: url)
    let partial = Config.load(from: url)
    Harness.expectEqual(partial.maxEntries, 7, "specified key is honoured")
    Harness.expectEqual(partial.filterSecrets, false, "unspecified key falls back to default")
    Harness.expectEqual(partial.hotkey, HotkeyConfig.default, "unspecified hotkey falls back to default")

    // Corrupt config falls back to defaults rather than crashing.
    try? Data("not json at all".utf8).write(to: url)
    Harness.expectEqual(Config.load(from: url), Config.default, "corrupt file yields defaults")

    // Round trip.
    var custom = Config.default
    custom.maxEntries = 25
    custom.filterSecrets = true
    try? custom.save(to: url)
    Harness.expectEqual(Config.load(from: url), custom, "config round-trips through disk")
}
