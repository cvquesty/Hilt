#!/usr/bin/env bash
# distribute-mac.sh — notarized Developer ID packages for direct distribution.
#
# Produces (in build/dist/):
#   Hilt-<version>.pkg   — Installer package → /Applications
#   Hilt-<version>.dmg   — Drag Hilt → Applications
#   Hilt-<version>.zip   — Portable app bundle
#   INSTALL.txt          — End-user install notes
#
# Prerequisites:
#   - Xcode signed into team QCLT43467P (Cloud Managed Developer ID Application)
#   - App Store Connect API key at .secrets/AuthKey_*.p8 (+ issuer.txt)
#   - Optional: "Developer ID Installer" identity in keychain to sign the .pkg
#     (if missing, the PKG is still built and the notarized app is embedded;
#      primary Gatekeeper trust comes from the stapled app + DMG/ZIP path)
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
PACKAGING="$ROOT/Packaging"

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

echo "→ Submitting app to Apple notary service…"
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
DIST_PKG="$DIST/Hilt-${VERSION}.pkg"
rm -f "$DIST_ZIP" "$DIST_DMG" "$DIST_PKG"

# --- ZIP ---
echo "→ Creating distribution zip…"
ditto -c -k --keepParent "$APP" "$DIST_ZIP"

# --- PKG installer (installs Hilt.app → /Applications) ---
echo "→ Creating installer package…"
PKG_ROOT="$DIST/pkg-root"
PKG_SCRATCH="$DIST/pkg-scratch"
rm -rf "$PKG_ROOT" "$PKG_SCRATCH"
mkdir -p "$PKG_ROOT/Applications" "$PKG_SCRATCH/resources"
cp -R "$APP" "$PKG_ROOT/Applications/Hilt.app"

# Installer UI resources
cp "$PACKAGING/welcome.html" "$PKG_SCRATCH/resources/"
cp "$PACKAGING/conclusion.html" "$PKG_SCRATCH/resources/"
cp "$ROOT/LICENSE" "$PKG_SCRATCH/resources/LICENSE"

# Keep Distribution.xml package version in sync with this build (not the XML declaration)
DIST_XML="$PKG_SCRATCH/Distribution.xml"
sed "s/pkg-ref id=\"org.questy.hilt\" version=\"[^\"]*\"/pkg-ref id=\"org.questy.hilt\" version=\"${VERSION}\"/" \
  "$PACKAGING/Distribution.xml" > "$DIST_XML"

COMPONENT_PKG="$PKG_SCRATCH/Hilt-component.pkg"
pkgbuild \
  --root "$PKG_ROOT" \
  --identifier "org.questy.hilt" \
  --version "$VERSION" \
  --install-location "/" \
  "$COMPONENT_PKG"

UNSIGNED_PKG="$PKG_SCRATCH/Hilt-unsigned.pkg"
productbuild \
  --distribution "$DIST_XML" \
  --resources "$PKG_SCRATCH/resources" \
  --package-path "$PKG_SCRATCH" \
  "$UNSIGNED_PKG"
INSTALLER_ID="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Installer:[^"]*\)".*/\1/p' | head -1 || true)"
if [[ -z "${INSTALLER_ID}" ]]; then
  # productsign needs codesigning policy; also search all identities
  INSTALLER_ID="$(security find-identity -v 2>/dev/null | sed -n 's/.*"\(Developer ID Installer:[^"]*\)".*/\1/p' | head -1 || true)"
fi

PKG_SIGNED=0
if [[ -n "${INSTALLER_ID}" ]]; then
  echo "→ Signing package with: $INSTALLER_ID"
  productsign --sign "$INSTALLER_ID" "$UNSIGNED_PKG" "$DIST_PKG"
  PKG_SIGNED=1
else
  echo "→ No Developer ID Installer identity in keychain — shipping unsigned product package."
  echo "  (App inside is still notarized Developer ID. Prefer DMG/ZIP for end users, or add a Developer ID Installer cert for a signed .pkg.)"
  cp "$UNSIGNED_PKG" "$DIST_PKG"
fi

if [[ "$PKG_SIGNED" -eq 1 ]]; then
  echo "→ Notarizing installer package…"
  xcrun notarytool submit "$DIST_PKG" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
  echo "→ Stapling ticket to package…"
  xcrun stapler staple "$DIST_PKG" || true
  spctl -a -vv -t install "$DIST_PKG" 2>&1 || true
fi

# --- DMG (app + Applications + install notes; include signed pkg when available) ---
echo "→ Creating distribution DMG…"
DMG_ROOT="$DIST/dmg-root"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP" "$DMG_ROOT/Hilt.app"
ln -s /Applications "$DMG_ROOT/Applications"
{
  echo "Hilt ${VERSION} (${BUILD})"
  echo ""
  cat "$PACKAGING/INSTALL.txt"
} > "$DMG_ROOT/Install Instructions.txt"
# Only put the .pkg on the DMG when it is Installer-signed (Gatekeeper-friendly).
if [[ "$PKG_SIGNED" -eq 1 ]]; then
  cp "$DIST_PKG" "$DMG_ROOT/Install Hilt.pkg"
fi
# One-click local install helper (copies the notarized app into Applications)
cat > "$DMG_ROOT/Install Hilt.command" << 'EOS'
#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/Hilt.app"
DEST="/Applications/Hilt.app"
if [[ ! -d "$SRC" ]]; then
  osascript -e 'display alert "Hilt installer" message "Hilt.app was not found next to this installer. Re-open the disk image and try again." as critical'
  exit 1
fi
if [[ -d "$DEST" ]]; then
  rm -rf "$DEST"
fi
ditto "$SRC" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
open "$DEST"
osascript -e 'display notification "Hilt is installed in Applications." with title "Hilt"'
EOS
chmod +x "$DMG_ROOT/Install Hilt.command"

TMP_DMG="$DIST/Hilt-tmp.dmg"
rm -f "$TMP_DMG"
hdiutil create -volname "Hilt ${VERSION}" -srcfolder "$DMG_ROOT" -ov -format UDRW "$TMP_DMG" >/dev/null
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DIST_DMG" >/dev/null
rm -f "$TMP_DMG"
rm -rf "$DMG_ROOT" "$PKG_ROOT" "$PKG_SCRATCH" "$ZIP_NOTARY"

# If package is unsigned, keep it for maintainers but do not market as primary.
if [[ "$PKG_SIGNED" -ne 1 ]]; then
  echo "→ Note: $DIST_PKG is not Installer-signed. Prefer DMG/ZIP for end users."
  echo "  Add a Developer ID Installer certificate to sign+notarize the .pkg."
fi

cp "$PACKAGING/INSTALL.txt" "$DIST/INSTALL.txt"

echo ""
echo "=== Distribution ready ==="
echo "  Version:  $VERSION ($BUILD)"
echo "  Signing:  Developer ID Application (Cloud Managed) — team $TEAM_ID"
echo "  Gatekeeper: Notarized Developer ID (app)"
if [[ "$PKG_SIGNED" -eq 1 ]]; then
  echo "  Installer: signed + notarized .pkg"
else
  echo "  Installer: DMG with Install Hilt.command (+ unsigned .pkg for later Installer cert)"
fi
echo ""
echo "  Recommended to send users:"
echo "    $DIST_DMG   ← open → double-click Install Hilt.command, or drag Hilt → Applications"
echo "    $DIST_ZIP   ← unzip and move Hilt.app to Applications"
if [[ "$PKG_SIGNED" -eq 1 ]]; then
  echo "    $DIST_PKG   ← double-click installer → /Applications"
fi
echo ""
echo "  First launch: if macOS warns, right-click → Open (rare after notarization)."
echo ""
ls -lh "$DIST_DMG" "$DIST_ZIP" "$DIST_PKG" "$DIST/INSTALL.txt"
