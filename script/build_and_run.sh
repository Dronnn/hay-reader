#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
pkill -x hay-read || true
BUILD_DIR="${TMPDIR:-/tmp}/hay-reader-build"
xcodebuild -project hay-read/hay-read.xcodeproj -scheme hay-read -configuration Debug -derivedDataPath "$BUILD_DIR" build
APP="$BUILD_DIR/Build/Products/Debug/hay-read.app"
case "${1:-run}" in
  --debug) lldb "$APP/Contents/MacOS/hay-read" ;;
  *) open "$APP" ;;
esac
if [ "${1:-}" = --verify ]; then sleep 1; pgrep -x hay-read; fi
if [ "${1:-}" = --logs ] || [ "${1:-}" = --telemetry ]; then
  /usr/bin/log stream --info --predicate 'subsystem == "com.mrmaier.hay.hay-read"'
fi
