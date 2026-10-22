#!/bin/zsh
# Uploads releases/Recall-<version>.dmg and releases/appcast.xml (made by make-dmg.sh) to the R2 bucket
# the license Worker serves. Downloads: raegent.com/recall/download → newest DMG; updates read
# raegent.com/recall/appcast.xml. The DMG goes up first so the feed never points at a missing file.
# Usage: ./scripts/publish-release.sh [version]   (default: the version in build/Recall.app)
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=${1:-$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/Recall.app/Contents/Info.plist)}
DMG=releases/Recall-$VERSION.dmg
[[ -f $DMG && -f releases/appcast.xml ]] || { echo "error: run ./scripts/make-dmg.sh first ($DMG or releases/appcast.xml missing)" >&2; exit 1; }
grep -q "Recall-$VERSION.dmg" releases/appcast.xml || { echo "error: appcast.xml has no entry for $VERSION" >&2; exit 1; }
cd server
wrangler r2 object put "recall-releases/Recall-$VERSION.dmg" --remote --file "../$DMG" --content-type application/x-apple-diskimage
wrangler r2 object put recall-releases/appcast.xml --remote --file ../releases/appcast.xml --content-type "application/xml; charset=utf-8"
echo "Published Recall $VERSION. Check: curl -sI https://recall-license.rishabhgupta4523.workers.dev/download/latest"
