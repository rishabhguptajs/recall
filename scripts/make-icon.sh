#!/bin/zsh
# Renders the app icon: layers into App/AppIcon.icon (Icon Composer format; Xcode also derives the
# icon for macOS 14/15 from it) and the complete framed icon into assets/icon.png.
set -euo pipefail
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
swift scripts/make-icon.swift "$TMP" >/dev/null
mkdir -p App/AppIcon.icon/Assets assets
cp "$TMP/blob.png" "$TMP/background.png" App/AppIcon.icon/Assets/
cp "$TMP/icon.png" assets/icon.png
rm -rf "$TMP"
echo "Wrote App/AppIcon.icon and assets/icon.png"
