import Foundation

/// A global hotkey binding, stored as a virtual keycode plus modifier names.
public struct HotkeyConfig: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: [String]

    public init(keyCode: UInt32, modifiers: [String]) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// ⌘⇧V — keyCode 9 is kVK_ANSI_V.
    ///
    /// Note this shadows "Paste and Match Style" in apps that bind it (Chrome,
    /// Slack, Notes, VS Code); those still offer it via their Edit menu.
    ///
    /// Carbon's `RegisterEventHotKey` cannot distinguish left from right
    /// modifiers — `cmdKey`/`shiftKey` match either side. Side-specific binding
    /// would need a CGEvent tap reading device-dependent flags, which requires
    /// Accessibility permission; Carbon was chosen precisely because it needs
    /// none.
    public static let `default` = HotkeyConfig(keyCode: 9, modifiers: ["command", "shift"])

    /// Carbon modifier mask for `RegisterEventHotKey`.
    /// Values are the Carbon constants: cmdKey 256, shiftKey 512, optionKey 2048, controlKey 4096.
    public var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        for modifier in modifiers {
            switch modifier.lowercased() {
            case "command", "cmd": mask |= 256
            case "shift":          mask |= 512
            case "option", "alt":  mask |= 2048
            case "control", "ctrl": mask |= 4096
            default: break
            }
        }
        return mask
    }
}

/// User-editable settings, read from `config.json`.
///
/// Decoding is deliberately tolerant: any missing key falls back to its default
/// so a hand-edited partial file stays valid.
public struct Config: Codable, Equatable, Sendable {
    public var maxEntries: Int
    public var hotkey: HotkeyConfig
    public var filterSecrets: Bool
    public var launchAtLogin: Bool
    /// Set once the Accessibility alert has been shown. Prevents nagging a user
    /// who cannot grant it — the permission is administrator-gated.
    public var hasAskedForAccessibility: Bool

    public init(
        maxEntries: Int, hotkey: HotkeyConfig, filterSecrets: Bool, launchAtLogin: Bool,
        hasAskedForAccessibility: Bool = false
    ) {
        self.maxEntries = maxEntries
        self.hotkey = hotkey
        self.filterSecrets = filterSecrets
        self.launchAtLogin = launchAtLogin
        self.hasAskedForAccessibility = hasAskedForAccessibility
    }

    public static let `default` = Config(
        maxEntries: 50,
        hotkey: .default,
        filterSecrets: false,
        launchAtLogin: true,
        hasAskedForAccessibility: false
    )

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = Config.default
        maxEntries = try container.decodeIfPresent(Int.self, forKey: .maxEntries) ?? fallback.maxEntries
        hotkey = try container.decodeIfPresent(HotkeyConfig.self, forKey: .hotkey) ?? fallback.hotkey
        filterSecrets = try container.decodeIfPresent(Bool.self, forKey: .filterSecrets) ?? fallback.filterSecrets
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? fallback.launchAtLogin
        hasAskedForAccessibility = try container.decodeIfPresent(Bool.self, forKey: .hasAskedForAccessibility)
            ?? fallback.hasAskedForAccessibility
    }

    /// Never throws: a missing or unreadable file yields defaults.
    public static func load(from url: URL) -> Config {
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(Config.self, from: data)
        else { return .default }
        return config
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}
