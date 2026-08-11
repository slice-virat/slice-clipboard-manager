# Clipboard Manager

A menu-bar clipboard history for macOS. Keeps your last 50 copied text
snippets; press **⌘⇧V** (command-shift-V) to search them and paste one back.

## Install

    git clone <this-repo-url> && cd slice-clipboard-manager
    ./setup.sh

That's it. The script checks your machine, builds the app, runs the tests, and
installs it to `~/Applications`. It needs **no administrator rights** and writes
nothing outside your home folder. Takes a couple of minutes the first time. 
**If it asks for any admin creds for accessibility, deny it**

Then look for the clipboard icon in your menu bar and press ⌘⇧V (command-shift-V).

To update later: `git pull && ./setup.sh`. To remove it: `make uninstall`.

### If setup.sh stops and asks for Command Line Tools

It needs the Swift compiler, which comes with Xcode's Command Line Tools:

    xcode-select --install

That opens a system dialog and downloads a few GB. **It may ask for an
administrator password** — if you don't have one, ask IT to run it, or ask a
colleague to build the app and send you the finished `ClipboardManager.app`
(a locally-built copy passed directly between machines works fine; a copy
downloaded from Slack or the web does not — macOS blocks those).

### Before you install: where your history is stored

Your clipboard history is written to
`~/Library/Application Support/ClipboardManager/history.json`, unencrypted.
It is readable only by your account and never leaves your Mac, but **it
includes anything you copy out of a password manager**.

To skip password-manager copies, set `"filterSecrets": true` in
`~/Library/Application Support/ClipboardManager/config.json` and restart the
app. No rebuild needed.

## Requirements

macOS 14 or later, and Swift 6.0 or later — Xcode's Command Line Tools are
enough, full Xcode is not required.

## Build and install

    make test      # run the ClipCore logic tests
    make app       # build build/ClipboardManager.app
    make install   # copy to ~/Applications and launch

Installs to `~/Applications`, so no administrator rights are needed.

`make app` builds for the current machine only and signs ad-hoc, which means
the result runs **only on the machine that built it**. That is why everyone
clones and runs `./setup.sh` rather than passing the app around — a locally
built app is never quarantined, so macOS lets it run without any certificate.

`make dist` exists for the other route: it produces a universal (Apple Silicon
+ Intel) bundle with the hardened runtime, ready for `make notarize`. Handing
someone a prebuilt app they download requires an Apple Developer ID
certificate and notarization — without those, Gatekeeper blocks it on every
machine but the one that built it, and the override needs administrator
rights. `make dist` warns you rather than letting you ship something broken.

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
| ⌘⇧V (command-shift-V) | Open the panel |
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
      "hotkey": { "keyCode": 9, "modifiers": ["command", "shift"] },
      "filterSecrets": false,
      "launchAtLogin": true,
      "hasAskedForAccessibility": false
    }

Any missing key falls back to its default. Restart the app after editing.

### Changing the hotkey

The default **⌘⇧V** shadows "Paste and Match Style" in Chrome, Slack, Notes,
and VS Code. Those apps still offer it from their Edit menu, but if you'd
rather keep the keystroke, edit `modifiers` and restart the app.

`modifiers` accepts any combination of `"command"`, `"shift"`, `"option"`, and
`"control"`. Two combinations with essentially no conflicts:

    "hotkey": { "keyCode": 9, "modifiers": ["control", "option"] }
    "hotkey": { "keyCode": 9, "modifiers": ["control", "shift"] }

`keyCode` is the physical key. A few common ones:

| Key | Code | | Key | Code | | Key | Code |
|-----|------|-|-----|------|-|-----|------|
| A | 0 | | H | 4 | | V | 9 |
| S | 1 | | G | 5 | | Space | 49 |
| D | 2 | | Z | 6 | | ` | 50 |
| F | 3 | | X | 7 | | C | 8 |

Left and right modifiers cannot be told apart — `"command"` matches either
side. Distinguishing them would need a different key-capture mechanism that
requires Accessibility permission, which this app deliberately avoids needing.

If the combination you pick is already claimed by another app, registration
fails and the menu-bar icon becomes a warning triangle explaining why.

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
