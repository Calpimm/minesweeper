#!/bin/bash
# Builds Minefield.app and a zip ready for a Homebrew cask.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
APP="build/Minefield.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Minefield"

rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Minefield"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Minefield</string>
  <key>CFBundleDisplayName</key><string>Minefield</string>
  <key>CFBundleIdentifier</key><string>com.example.minefield</string>
  <key>CFBundleExecutable</key><string>Minefield</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.puzzle-games</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature (enough for local use; notarization needs a Developer ID).
codesign --force --deep -s - "$APP"

ditto -c -k --keepParent "$APP" "build/Minefield-${VERSION}.zip"
echo "Built $APP and build/Minefield-${VERSION}.zip"
shasum -a 256 "build/Minefield-${VERSION}.zip"
