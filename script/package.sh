#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUILD_DIR="${TMPDIR:-/tmp}/hay-reader-release"
VERSION=1.0.1
xcodebuild -project hay-read/hay-read.xcodeproj -scheme hay-read -configuration Release -derivedDataPath "$BUILD_DIR" build
STAGING="$BUILD_DIR/dmg"
mkdir -p "$STAGING" dist
APP="$STAGING/Armenian Speaker.app"
if [ -d "$APP" ]; then rm -rf "$APP"; fi
ditto "$BUILD_DIR/Build/Products/Release/hay-read.app" "$APP"
xattr -cr "$APP"
codesign --verify --deep --strict "$APP"
ln -sfn /Applications "$STAGING/Applications"
hdiutil create -volname 'Armenian Speaker' -srcfolder "$STAGING" -ov -format UDZO "dist/Armenian-Speaker-$VERSION-arm64.dmg"
hdiutil verify "dist/Armenian-Speaker-$VERSION-arm64.dmg"
shasum -a 256 "dist/Armenian-Speaker-$VERSION-arm64.dmg" > "dist/SHA256SUMS"
