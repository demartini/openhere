#!/bin/bash
# Signs a built OpenHere.app (and its Finder extension) after an unsigned build.
#   sign_app.sh <OpenHere.app> [identity]     identity defaults to "-" (ad hoc)
set -euo pipefail
APP="${1:?usage: sign_app.sh path/to/OpenHere.app [identity]}"
IDENTITY="${2:--}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

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
sign --entitlements "$ROOT/OpenHereFinderExtension/OpenHereFinderExtension.entitlements" \
  "$APP/Contents/PlugIns/OpenHereFinderExtension.appex"
sign --entitlements "$ROOT/OpenHere/OpenHere.entitlements" "$APP"
codesign --verify --deep --strict "$APP"
echo "signed ($IDENTITY): $APP"
