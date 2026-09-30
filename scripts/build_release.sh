#!/bin/bash
# Builds OpenHere and packages it as a DMG + SHA-256 for GitHub Releases. No notarization.
#
#   scripts/build_release.sh                       ad-hoc signature (works for everyone, no Apple account)
#   TEAM_ID=ABCDE12345 SIGNING_IDENTITY="Apple Development: Name (XXXX)" scripts/build_release.sh
#                                                  signs with a development certificate
# Optional: VERSION=1.2.3 (overrides MARKETING_VERSION), BUILD_NUMBER=42
#
# The app is not notarized, so a browser-downloaded copy is quarantined by Gatekeeper; the in-app
# updater removes the quarantine flag, see docs/RELEASING.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/release"
IDENTITY="${SIGNING_IDENTITY:--}"
rm -rf "$BUILD"; mkdir -p "$BUILD"

extra=()
[[ -n "${VERSION:-}" ]] && extra+=("MARKETING_VERSION=$VERSION")
[[ -n "${BUILD_NUMBER:-}" ]] && extra+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")
[[ -n "${TEAM_ID:-}" ]] && extra+=("DEVELOPMENT_TEAM=$TEAM_ID")

echo "▸ Building (Release)"
xcodebuild build \
  -project "$ROOT/OpenHere.xcodeproj" -scheme OpenHere -configuration Release \
  -derivedDataPath "$BUILD/DerivedData" CODE_SIGNING_ALLOWED=NO \
  ${extra[@]+"${extra[@]}"}

APP="$BUILD/OpenHere.app"
cp -R "$BUILD/DerivedData/Build/Products/Release/OpenHere.app" "$APP"

echo "▸ Signing"
"$ROOT/scripts/sign_app.sh" "$APP" "$IDENTITY"

VERSION_STRING="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$BUILD/OpenHere-$VERSION_STRING.dmg"
echo "▸ Creating DMG"
command -v create-dmg >/dev/null || { echo "create-dmg is required: brew install create-dmg" >&2; exit 1; }
STAGE="$(mktemp -d)"; trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/OpenHere.app"
rm -f "$DMG"
# Window 660x440 to match assets/dmg/background.png (drawn at 2x). Finder chrome (title bar, tab bar, path bar)
# eats up to ~100 pt of it, so the art keeps everything important in the top ~340 pt. Icon centres: x=180 / x=480, y=200.
create-dmg \
  --volname "OpenHere" \
  --volicon "$APP/Contents/Resources/AppIcon.icns" \
  --background "$ROOT/assets/dmg/background.png" \
  --window-pos 200 120 \
  --window-size 660 440 \
  --icon-size 112 \
  --text-size 13 \
  --icon "OpenHere.app" 180 200 \
  --hide-extension "OpenHere.app" \
  --app-drop-link 480 200 \
  --no-internet-enable \
  "$DMG" "$STAGE"
( cd "$BUILD" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256" )
echo "✔ $DMG"; cat "$DMG.sha256"
