#!/bin/bash
# Install or update Feelpad from the latest GitHub release.
#   curl -fsSL https://raw.githubusercontent.com/loganprosser/mac-feelpad/main/install.sh | bash
set -euo pipefail

[[ "$(uname -m)" == arm64 ]] || { echo "Feelpad needs a Mac with Apple silicon (M1 or newer)."; exit 1; }
macos="$(sw_vers -productVersion)"
(( ${macos%%.*} >= 15 )) || { echo "Feelpad needs macOS 15 or later (this Mac has $macos)."; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "Downloading Feelpad..."
curl -fsSL -o "$tmp/Feelpad.zip" https://github.com/loganprosser/mac-feelpad/releases/latest/download/Feelpad.zip
ditto -x -k "$tmp/Feelpad.zip" "$tmp"

dest=/Applications
[[ -w "$dest" ]] || { dest="$HOME/Applications"; mkdir -p "$dest"; }
osascript -e 'quit app "Feelpad"' >/dev/null 2>&1 || true
rm -rf "$dest/Feelpad.app"
ditto "$tmp/Feelpad.app" "$dest/Feelpad.app"
open "$dest/Feelpad.app"
echo "Installed $dest/Feelpad.app. Look for the hand icon in the menu bar."
