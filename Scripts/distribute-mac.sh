#!/usr/bin/env bash
# distribute-mac.sh — build a notarized Developer ID package others can install.
# Output: build/dist/Hilt-<version>.zip and Hilt-<version>.dmg
#
# Prerequisites:
#   - Xcode signed into team QCLT43467P (Cloud Managed Developer ID)
#   - App Store Connect API key at .secrets/AuthKey_*.p8 (+ issuer.txt)
#   - Notary profile "hilt-notary" (created automatically on first run)
#
# Usage: bash Scripts/distribute-mac.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TEAM_ID="QCLT43467P"
OUT="$ROOT/build"
DIST="$OUT/dist"
ARCHIVE="$OUT/Hilt.xcarchive"
EXPORT="$OUT/export-developer-id"
SECRETS="$ROOT/.secrets"
NOTARY_PROFILE="${HILT_NOTARY_PROFILE:-hilt-notary}"
EXPORT_PLIST="$ROOT/ExportOptions-DeveloperID.plist"

echo "=== Hilt macOS direct distribution ($(date -u +%Y-%m-%dT%H:%MZ)) ==="

if [[ ! -f "$EXPORT_PLIST" ]]; then
  cat > "$EXPORT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
</dict>
</plist>
EOF
fi

# Resolve API key for notarytool
KEY_FILE="$(ls "$SECRETS"/AuthKey_*.p8 2>/dev/null | head -1 || true)"
if [[ -z "$KEY_FILE" ]]; then
  echo "error: no App Store Connect API key at $SECRETS/AuthKey_*.p8" >&2
  exit 1
fi
KEY_ID="$(basename "$KEY_FILE" | sed 's/AuthKey_//;s/\.p8//')"
ISSUER="$(tr -d '[:space:]' < "$SECRETS/issuer.txt")"

echo "→ Ensuring notary credentials ($NOTARY_PROFILE)…"
xcrun notarytool store-credentials "$NOTARY_PROFILE" \
  --key "$KEY_FILE" \
  --key-id "$KEY_ID" \
  --issuer "$ISSUER" \
  --validate >/dev/null

if command -v swift >/dev/null 2>&1; then
  echo "→ swift test"
  swift test
fi

echo "→ Archiving (Release, generic macOS)…"
rm -rf "$ARCHIVE" "$EXPORT"
mkdir -p "$OUT"
xcodebuild -project Hilt.xcodeproj -scheme Hilt \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive

echo "→ Exporting Developer ID (Cloud Managed)…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -exportPath "$EXPORT" \
  -allowProvisioningUpdates

APP="$EXPORT/Hilt.app"
if [[ ! -d "$APP" ]]; then
  echo "error: export did not produce Hilt.app" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
echo "→ Built Hilt $VERSION ($BUILD)"

mkdir -p "$DIST"
ZIP_NOTARY="$DIST/Hilt-notarize.zip"
rm -f "$ZIP_NOTARY"
echo "→ Zipping for notarization…"
ditto -c -k --keepParent "$APP" "$ZIP_NOTARY"

echo "→ Submitting to Apple notary service…"
xcrun notarytool submit "$ZIP_NOTARY" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "→ Stapling ticket to app…"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "→ Gatekeeper check…"
spctl -a -vv "$APP"

DIST_ZIP="$DIST/Hilt-${VERSION}.zip"
DIST_DMG="$DIST/Hilt-${VERSION}.dmg"
rm -f "$DIST_ZIP" "$DIST_DMG"

echo "→ Creating distribution zip…"
ditto -c -k --keepParent "$APP" "$DIST_ZIP"

echo "→ Creating distribution DMG…"
DMG_ROOT="$DIST/dmg-root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP" "$DMG_ROOT/Hilt.app"
ln -s /Applications "$DMG_ROOT/Applications"
TMP_DMG="$DIST/Hilt-tmp.dmg"
rm -f "$TMP_DMG"
hdiutil create -volname "Hilt ${VERSION}" -srcfolder "$DMG_ROOT" -ov -format UDRW "$TMP_DMG" >/dev/null
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DIST_DMG" >/dev/null
rm -f "$TMP_DMG"
rm -rf "$DMG_ROOT"

# Optional: clean intermediate notary zip
rm -f "$ZIP_NOTARY"

echo ""
echo "=== Distribution ready ==="
echo "  Version:  $VERSION ($BUILD)"
echo "  Signing:  Developer ID Application (Cloud Managed) — team $TEAM_ID"
echo "  Gatekeeper: Notarized Developer ID"
echo ""
echo "  Send either file to users:"
echo "    $DIST_DMG"
echo "    $DIST_ZIP"
echo ""
echo "  Users: open the DMG and drag Hilt → Applications, or unzip and open Hilt.app."
echo "  First launch: if macOS warns, right-click → Open (rare after notarization)."
echo ""
ls -lh "$DIST_DMG" "$DIST_ZIP"
