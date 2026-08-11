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
    Harness.expectEqual(d.hotkey.modifiers, ["command", "shift"], "default modifiers are command+shift")
    Harness.expectEqual(d.hasAskedForAccessibility, false, "accessibility prompt has not been shown by default")

    // cmdKey (256) | shiftKey (512) == 768
    Harness.expectEqual(d.hotkey.carbonModifiers, 768, "default command+shift maps to Carbon 768")
    Harness.expectEqual(
        HotkeyConfig(keyCode: 9, modifiers: ["control", "option"]).carbonModifiers, 6144,
        "control+option maps to Carbon 6144")
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
    Harness.expectEqual(
        partial.hasAskedForAccessibility, false,
        "config file written without the key loads with hasAskedForAccessibility false")

    // A config file that does specify the key is honoured.
    try? Data(#"{"hasAskedForAccessibility": true}"#.utf8).write(to: url)
    Harness.expectEqual(
        Config.load(from: url).hasAskedForAccessibility, true,
        "hasAskedForAccessibility true in the file is honoured")

    // Corrupt config falls back to defaults rather than crashing.
    try? Data("not json at all".utf8).write(to: url)
    Harness.expectEqual(Config.load(from: url), Config.default, "corrupt file yields defaults")

    // Round trip.
    var custom = Config.default
    custom.maxEntries = 25
    custom.filterSecrets = true
    custom.hasAskedForAccessibility = true
    try? custom.save(to: url)
    let roundTripped = Config.load(from: url)
    Harness.expectEqual(roundTripped, custom, "config round-trips through disk")
    Harness.expectEqual(
        roundTripped.hasAskedForAccessibility, true, "hasAskedForAccessibility survives save/load round trip")
}
