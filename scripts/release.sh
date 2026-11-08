#!/bin/bash
# Build Feelpad.app and publish it as a GitHub release that install.sh downloads.
#   ./scripts/release.sh 0.1.0
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

version="${1:?usage: scripts/release.sh <version, e.g. 0.1.0>}"
[[ -z "$(git status --porcelain)" ]] || { echo "Commit your changes first."; exit 1; }
git fetch -q
[[ -z "$(git log @{u}..)" ]] || { echo "Push your commits first."; exit 1; }

./scripts/test.sh
VERSION="$version" ./scripts/bundle.sh
rm -f dist/Feelpad.zip
ditto -c -k --keepParent dist/Feelpad.app dist/Feelpad.zip

gh release create "v$version" dist/Feelpad.zip --title "Feelpad $version" --notes "Install or update:

\`\`\`sh
curl -fsSL https://raw.githubusercontent.com/loganprosser/mac-feelpad/main/install.sh | bash
\`\`\`

Or download Feelpad.zip below, unzip it, and drag Feelpad.app to Applications. Requires an Apple silicon Mac with macOS 15 or later."
