#!/usr/bin/env bash
# ship-mac.sh — archive Hilt and upload to App Store Connect / TestFlight (macOS)
# Usage: bash Scripts/ship-mac.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Hilt macOS ship ($(date -u +%Y-%m-%dT%H:%MZ)) ==="
echo "Version: $(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Hilt/Info.plist 2>/dev/null || true)"
echo "  (resolved from Xcode MARKETING_VERSION / CURRENT_PROJECT_VERSION at archive time)"

# Quick unit tests before archive
if command -v swift >/dev/null 2>&1; then
  echo "→ swift test"
  swift test
fi

bash "$ROOT/Scripts/archive-mac.sh"

echo "=== Ship complete ==="
echo "  App Store Connect: https://appstoreconnect.apple.com/apps/6788101386/testflight/macos"
echo "  Store name: Hilt for e-Sword X  |  bundle: org.questy.hilt  |  team: QCLT43467P"
echo "  After processing (often a few minutes): open the TestFlight app on this Mac and install."
