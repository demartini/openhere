#!/bin/bash
# Signs a built OpenHere.app (and its Finder extension) after an unsigned build.
#   sign_app.sh <OpenHere.app> [identity]     identity defaults to "-" (ad hoc)
# Set TEAM_ID when using a real identity so the App Group gets its team prefix. It must match the
# DEVELOPMENT_TEAM the app was built with (the prefix is baked into Info.plist at build time).
set -euo pipefail
APP="${1:?usage: sign_app.sh path/to/OpenHere.app [identity]}"
IDENTITY="${2:--}"
PREFIX=""
[[ -n "${TEAM_ID:-}" ]] && PREFIX="${TEAM_ID}."

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
resolve() { sed "s/\\\$(TeamIdentifierPrefix)/$PREFIX/g" "$1" > "$2"; }
resolve "$ROOT/OpenHere/OpenHere.entitlements" "$WORK/app.entitlements"
resolve "$ROOT/OpenHereFinderExtension/OpenHereFinderExtension.entitlements" "$WORK/ext.entitlements"

# An unsigned build cannot expand $(TeamIdentifierPrefix); keep Info.plist and entitlements in sync.
for plist in "$APP/Contents/Info.plist" "$APP/Contents/PlugIns/OpenHereFinderExtension.appex/Contents/Info.plist"; do
  /usr/libexec/PlistBuddy -c "Set :OpenHereAppGroup ${PREFIX}group.dev.demartini.openhere" "$plist"
done

# Sparkle: this app is not sandboxed, so the sandbox helper XPC services are not needed. Removing them
# avoids re-signing sandboxed helpers whose entitlements ad-hoc signing would strip.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE" ]]; then
  rm -rf "$SPARKLE/Versions/B/XPCServices" "$SPARKLE/XPCServices"
fi

sign() { codesign --force --sign "$IDENTITY" --options runtime --timestamp=none "$@"; }
find "$APP" -name '*.dylib' -exec codesign --force --sign "$IDENTITY" {} \;
if [[ -d "$SPARKLE" ]]; then
  # Inside-out, without --deep.
  sign "$SPARKLE/Versions/B/Autoupdate"
  sign "$SPARKLE/Versions/B/Updater.app"
  sign "$SPARKLE"
fi
sign --entitlements "$WORK/ext.entitlements" "$APP/Contents/PlugIns/OpenHereFinderExtension.appex"
sign --entitlements "$WORK/app.entitlements" "$APP"
codesign --verify --deep --strict "$APP"
echo "signed ($IDENTITY): $APP"
