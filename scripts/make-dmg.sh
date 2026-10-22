#!/bin/zsh
# Builds a signed Release Recall.app, packages it as build/Recall-<version>.dmg
# (app + Applications shortcut, so people can drag to install), then copies it to releases/
# and regenerates releases/appcast.xml, the update feed Sparkle reads.
# Before each release, raise CFBundleShortVersionString and CFBundleVersion in project.yml.
# RECALL_DOWNLOAD_BASE is the public folder the DMGs are served from (default below).
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

# Update feed. Sparkle compares CFBundleVersion, so every release needs a higher one.
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" build/Recall.app/Contents/Info.plist)
KEY=keys/sparkle-private-key.txt
BIN=build/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin
[[ -f $KEY ]] || { echo "error: $KEY missing (restore it from the keys backup)" >&2; exit 1; }
mkdir -p releases
if [[ -f releases/Recall-$VERSION.dmg && "${REPLACE:-0}" != "1" ]]; then
  echo "error: releases/Recall-$VERSION.dmg exists. Raise the version in project.yml (or REPLACE=1)." >&2; exit 1
fi
cp "$OUT" releases/
BASE=${RECALL_DOWNLOAD_BASE:-https://raegent.com/recall/download/}
"$BIN/generate_appcast" --ed-key-file "$KEY" --download-url-prefix "$BASE" \
  --link https://raegent.com/recall -o releases/appcast.xml releases
echo "Updated releases/appcast.xml (version $VERSION, build $BUILD)."
echo "Publish: releases/Recall-$VERSION.dmg -> $BASE, releases/appcast.xml -> https://raegent.com/recall/appcast.xml"
