#!/bin/bash
# Build a release Feelpad.app into dist/ (Apple silicon, ad-hoc signed).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

swift build -c release --arch arm64
bin="$(swift build -c release --arch arm64 --show-bin-path)/Feelpad"

app="$root/dist/Feelpad.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/Feelpad"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"

codesign --force --sign - "$app"

echo "Built: $app"
echo "Run it with: open \"$app\""
