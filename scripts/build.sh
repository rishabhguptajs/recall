#!/bin/zsh
# Generate the Xcode project and build Recall.app into ./build
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG=${CONFIG:-Debug}
SIGN_ID="Recall Developer"
xcodegen generate --quiet
xcodebuild -project Recall.xcodeproj -scheme Recall -configuration "$CONFIG" \
  -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build -quiet
rm -rf build/Recall.app
cp -R "build/DerivedData/Build/Products/$CONFIG/Recall.app" build/Recall.app

# Sign with the stable self-signed certificate (scripts/make-signing-cert.sh) so macOS keeps
# folder permissions across builds. Falls back to the ad-hoc signature if it isn't installed.
if security find-certificate -c "$SIGN_ID" >/dev/null 2>&1; then
  codesign --force --sign "$SIGN_ID" --timestamp=none build/Recall.app
  echo "Signed with \"$SIGN_ID\""
else
  echo "warning: \"$SIGN_ID\" certificate not found, app is signed ad hoc (run scripts/make-signing-cert.sh)"
fi
echo "Built build/Recall.app ($CONFIG)"

if [[ "${INSTALL:-1}" == "1" ]]; then
  pkill -x Recall || true
  mkdir -p ~/Applications && rm -rf ~/Applications/Recall.app
  cp -R build/Recall.app ~/Applications/Recall.app
  echo "Installed ~/Applications/Recall.app"
fi
