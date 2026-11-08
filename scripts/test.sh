#!/bin/bash
# Run the tests. With only Command Line Tools (no Xcode), swift test can't find the Swift Testing
# macro plugin on its own, so pass its path explicitly.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

plugins=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
if [[ "$(xcode-select -p)" == /Library/Developer/CommandLineTools && -d "$plugins" ]]; then
    exec swift test -Xswiftc -plugin-path -Xswiftc "$plugins" "$@"
fi
exec swift test "$@"
