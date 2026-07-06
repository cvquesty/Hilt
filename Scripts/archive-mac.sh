#!/usr/bin/env bash
# Archive Hilt for Mac App Store Connect / TestFlight upload.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/build"
mkdir -p "$OUT"

echo "→ Archiving Hilt (Release, generic macOS)…"
xcodebuild -project Hilt.xcodeproj -scheme Hilt \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$OUT/Hilt.xcarchive" \
  archive

echo "→ Exporting / uploading to App Store Connect…"
xcodebuild -exportArchive \
  -archivePath "$OUT/Hilt.xcarchive" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$OUT/export"

echo "Done. Check App Store Connect / TestFlight for processing."
