#!/bin/zsh
# Generate the Xcode project and build Recall.app into ./build
set -euo pipefail
cd "$(dirname "$0")/.."
CONFIG=${CONFIG:-Debug}
xcodegen generate --quiet
xcodebuild -project Recall.xcodeproj -scheme Recall -configuration "$CONFIG" \
  -derivedDataPath build/DerivedData -destination 'platform=macOS,arch=arm64' build -quiet
rm -rf build/Recall.app
cp -R "build/DerivedData/Build/Products/$CONFIG/Recall.app" build/Recall.app
echo "Built build/Recall.app"
if [[ "${INSTALL:-1}" == "1" ]]; then
  pkill -x Recall || true
  mkdir -p ~/Applications && rm -rf ~/Applications/Recall.app
  cp -R build/Recall.app ~/Applications/Recall.app
  echo "Installed ~/Applications/Recall.app"
fi
