# Clipboard Manager

A menu-bar clipboard history for macOS. Keeps your last 50 copied text
snippets; press ⌃⌥V to search them and paste one into whatever app you
were using.

## Requirements

macOS 14 or later. Swift 6.3 toolchain (Command Line Tools are enough —
full Xcode is not required).

## Build and install

    make test      # run the ClipCore logic tests
    make app       # build build/ClipboardManager.app
    make install   # copy to ~/Applications and launch

Installs to `~/Applications`, so no administrator rights are needed.

On first launch you are asked once for Accessibility access. It is needed
only to send ⌘V to the app you were using. **Granting it requires an
administrator**; without it the app runs in copy-only mode, where choosing
an entry puts it on the clipboard and you press ⌘V yourself. Everything
else — the hotkey, search, keyboard navigation, history, launch at login —
works either way, because the hotkey uses Carbon rather than an event tap.

The prompt appears at most once. If you later gain administrator access,
use "Enable Auto-Paste…" in the menu-bar menu to request it again.

## Usage

| Key | Action |
|---|---|
| ⌃⌥V | Open the panel |
| Type | Filter the history |
| ↑ / ↓ | Move the selection |
| ⌘1–⌘9 | Paste that row |
| Enter | Paste the selected row |
| Esc | Close without pasting |

Anything you select moves to the top of the history, as does re-copying
something already in it.

## Configuration

`~/Library/Application Support/ClipboardManager/config.json`:

    {
      "maxEntries": 50,
      "hotkey": { "keyCode": 9, "modifiers": ["control", "option"] },
      "filterSecrets": false,
      "launchAtLogin": true,
      "hasAskedForAccessibility": false
    }

Any missing key falls back to its default. Restart the app after editing.

`filterSecrets` is **off**: everything you copy, including passwords copied
from a password manager, is stored in plaintext in `history.json` (mode
0600, in the same directory). Set it to `true` to skip copies marked
concealed by 1Password, Keychain Access, and similar tools.

## Development note

`swift test` does not work with Command Line Tools alone — neither XCTest
nor swift-testing ships with them. Tests are a plain executable target:
run `swift run ClipTests` (or `make test`).

Accessibility permission is keyed to the code signature, and the ad-hoc
signature changes on every build, so expect to re-grant access after each
`make install` during development.
