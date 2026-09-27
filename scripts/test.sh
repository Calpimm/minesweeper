#!/bin/bash
# Runs the Swift tests. With only the Command Line Tools installed (no Xcode),
# swift-testing needs a few extra flags to be found.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(xcode-select -p)" == */CommandLineTools ]]; then
  F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
  exec swift test -Xswiftc -F"$F" -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
    -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F" "$@"
fi
exec swift test "$@"
