#!/bin/bash
# Signs a release DMG with the Sparkle EdDSA key and writes the appcast that GitHub Pages serves.
#   scripts/make_appcast.sh <OpenHere-x.y.z.dmg> [output appcast.xml]
# The private key comes from $SPARKLE_ED_PRIVATE_KEY (CI; the text produced by `generate_keys -x`)
# or, when unset, from your login keychain (where `generate_keys` stored it).
set -euo pipefail

DMG="${1:?usage: make_appcast.sh OpenHere-x.y.z.dmg [appcast.xml]}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${2:-$ROOT/site/public/appcast.xml}"
REPO="${REPOSITORY:-demartini/openhere}"
PAGES_URL="https://${REPO%%/*}.github.io/${REPO##*/}/"

SIGN_UPDATE="$(find "$ROOT/build" -path '*artifacts/sparkle*' -name sign_update -type f 2>/dev/null | head -1)"
[[ -x "$SIGN_UPDATE" ]] || { echo "sign_update not found; build the app once so SwiftPM fetches Sparkle" >&2; exit 1; }

APP_DIR="$(mktemp -d)"; trap 'rm -rf "$APP_DIR"' EXIT
hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$APP_DIR" "$DMG" >/dev/null
PLIST="$APP_DIR/OpenHere.app/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$PLIST")"
MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$PLIST")"
hdiutil detach -force "$APP_DIR" >/dev/null

if [[ -n "${SPARKLE_ED_PRIVATE_KEY:-}" ]]; then
  KEY_FILE="$(mktemp)"; trap 'rm -rf "$APP_DIR" "$KEY_FILE"' EXIT
  printf '%s' "$SPARKLE_ED_PRIVATE_KEY" > "$KEY_FILE"
  SIGNATURE="$("$SIGN_UPDATE" --ed-key-file "$KEY_FILE" "$DMG")"
else
  SIGNATURE="$("$SIGN_UPDATE" "$DMG")"
fi
# SIGNATURE looks like: sparkle:edSignature="…" length="…"

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>OpenHere</title>
    <link>${PAGES_URL}</link>
    <description>OpenHere updates</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MIN_OS}</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>https://github.com/${REPO}/releases/tag/v${VERSION}</sparkle:releaseNotesLink>
      <enclosure url="https://github.com/${REPO}/releases/download/v${VERSION}/$(basename "$DMG")"
                 ${SIGNATURE}
                 type="application/octet-stream"/>
    </item>
  </channel>
</rss>
XML
echo "✔ $OUT (version $VERSION, build $BUILD)"
