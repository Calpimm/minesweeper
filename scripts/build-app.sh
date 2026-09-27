#!/bin/bash
# Builds build/Minesweeper.app and build/Minesweeper-<version>.zip.
#
# The version comes from Sources/Minesweeper/AppInfo.swift.
# Optional environment:
#   UNIVERSAL=1        build for Apple silicon and Intel (needs full Xcode)
#   SIGN_IDENTITY=...  "Developer ID Application: …"; ad-hoc signed when unset
#   API_BASE_URL=...   leaderboard server baked into Info.plist
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(scripts/version.sh)"
APP="build/Minesweeper.app"
ZIP="build/Minesweeper-${VERSION}.zip"

ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == 1 ]]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi
swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/Minesweeper"

rm -rf build && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Minesweeper"

# App icon, drawn from the same pixel art as the game.
"$BIN" --export-iconset build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf build/AppIcon.iconset

API_ENTRY=""
if [[ -n "${API_BASE_URL:-}" ]]; then
  API_ENTRY="<key>MSApiBaseURL</key><string>${API_BASE_URL}</string>"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Minesweeper</string>
  <key>CFBundleDisplayName</key><string>Minesweeper</string>
  <key>CFBundleIdentifier</key><string>com.calpimm.minesweeper</string>
  <key>CFBundleExecutable</key><string>Minesweeper</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.puzzle-games</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>© $(date +%Y) Calpimm. MIT License.</string>
  ${API_ENTRY}
</dict>
</plist>
PLIST

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  # Hardened runtime + secure timestamp are required for notarization.
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  codesign --force --sign - "$APP"
fi
codesign --verify --strict --verbose=1 "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"
echo "Built $APP and $ZIP (version $VERSION)"
