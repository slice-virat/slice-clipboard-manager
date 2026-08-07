#!/bin/bash
#
# Clipboard Manager — one-command setup.
#
#   ./setup.sh
#
# Builds the app from source and installs it to ~/Applications. Needs no
# administrator rights: nothing is written outside your home folder.

set -euo pipefail

APP_NAME="ClipboardManager"
INSTALL_DIR="$HOME/Applications"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
die()  { printf '\n\033[31m✗ %s\033[0m\n\n' "$1" >&2; exit 1; }

cd "$(dirname "$0")"

bold "Clipboard Manager setup"
echo

# ---------------------------------------------------------------- checks ----

macos_major=$(sw_vers -productVersion | cut -d. -f1)
if [ "$macos_major" -lt 14 ]; then
    die "Needs macOS 14 or later. You have $(sw_vers -productVersion)."
fi
ok "macOS $(sw_vers -productVersion)"

if ! xcode-select -p >/dev/null 2>&1; then
    cat <<'EOF'

Xcode Command Line Tools are not installed. They provide the Swift compiler.

Install them with:

    xcode-select --install

A dialog will appear; the download is a few GB and takes a while. Note that
it may ask for an administrator password — if you don't have one, ask IT to
run it, or ask a colleague to send you a prebuilt copy of the app instead.

Re-run ./setup.sh once it finishes.

EOF
    exit 1
fi
ok "Command Line Tools at $(xcode-select -p)"

command -v swift >/dev/null 2>&1 || die "swift not found on PATH, despite Command Line Tools being installed. Try: sudo xcode-select --reset"

swift_version=$(swift --version 2>&1 | grep -oE 'Apple Swift version [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+' | head -1)
swift_major=${swift_version%%.*}
if [ -z "$swift_version" ] || [ "$swift_major" -lt 6 ]; then
    die "Needs Swift 6.0 or later; found ${swift_version:-unknown}. Update Xcode or the Command Line Tools, then re-run."
fi
ok "Swift $swift_version"

echo

# ----------------------------------------------------------------- build ----

bold "Building (a minute or two the first time)"
if ! swift build -c release >/tmp/clipboard-build.log 2>&1; then
    tail -30 /tmp/clipboard-build.log >&2
    die "Build failed. Full log: /tmp/clipboard-build.log"
fi
ok "Built"

if ! swift run ClipTests >/tmp/clipboard-tests.log 2>&1; then
    tail -20 /tmp/clipboard-tests.log >&2
    die "Tests failed — please report this. Full log: /tmp/clipboard-tests.log"
fi
ok "$(grep -oE 'PASS — [0-9]+ assertions' /tmp/clipboard-tests.log || echo 'Tests passed')"

echo

# --------------------------------------------------------------- install ----

bold "Installing to $INSTALL_DIR"

if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    pkill -x "$APP_NAME" || true
    sleep 1
    ok "Stopped the running copy"
fi

make app >/dev/null 2>&1 || die "Could not assemble the app bundle."
mkdir -p "$INSTALL_DIR"
rm -rf "${INSTALL_DIR:?}/$APP_NAME.app"
cp -R "build/$APP_NAME.app" "$INSTALL_DIR/"
ok "Installed"

open "$INSTALL_DIR/$APP_NAME.app"
ok "Launched"

echo
bold "Done — look for the clipboard icon in your menu bar"
cat <<'EOF'

  Press  ⌃⌥V  (control-option-V) to open your clipboard history.

  Type to search, ↑/↓ to move, ⌘1-⌘9 to jump, Enter to pick, Esc to close.
  It starts automatically when you log in.

  You'll be asked once for Accessibility permission. Say yes and picking an
  entry pastes it straight into whatever you were working in. Say no — or if
  you don't have admin rights to grant it — and everything still works: the
  entry goes to your clipboard and you press ⌘V yourself.

EOF
warn "Your clipboard history is saved unencrypted in your home folder,"
warn "including anything you copy out of a password manager."
echo   "    To skip password-manager copies, edit"
echo   "    ~/Library/Application Support/ClipboardManager/config.json,"
echo   "    set \"filterSecrets\": true, and restart the app."
echo
echo   "  To update later:  git pull && ./setup.sh"
echo   "  To uninstall:     make uninstall"
echo
