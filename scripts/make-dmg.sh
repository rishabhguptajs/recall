#!/bin/zsh
# Builds a signed Release Recall.app and packages it as build/Recall-<version>.dmg
# (app + Applications shortcut, so people can drag to install).
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG=Release INSTALL=0 ./scripts/build.sh
SERVER=$(/usr/libexec/PlistBuddy -c "Print RecallLicenseServer" build/Recall.app/Contents/Info.plist)
if [[ "$SERVER" == *REPLACE-ME* || "$SERVER" != https://* ]]; then
  echo "error: Release license server is \"$SERVER\". Deploy server/ and set RECALL_LICENSE_SERVER (Release) in project.yml first." >&2
  [[ "${ALLOW_PLACEHOLDER:-0}" == "1" ]] || exit 1
fi
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" build/Recall.app/Contents/Info.plist)
STAGE=build/dmg-stage
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R build/Recall.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
OUT="build/Recall-$VERSION.dmg"
rm -f "$OUT"
hdiutil create -volname "Recall" -srcfolder "$STAGE" -fs HFS+ -format UDZO -quiet "$OUT"
rm -rf "$STAGE"
if security find-certificate -c "Recall Developer" >/dev/null 2>&1; then
  codesign --force --sign "Recall Developer" --timestamp=none "$OUT"
fi
echo "Created $OUT ($(du -h "$OUT" | cut -f1))"
