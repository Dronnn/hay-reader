#!/bin/bash
set -euo pipefail
export MACOSX_DEPLOYMENT_TARGET=14.0
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
REV=404aefedbd74baa0bd43e451bc407a2b3aace0f5
if [ ! -f .local/runtime/lib/libpiper.dylib ]; then
  command -v cmake >/dev/null || { echo 'error: Install CMake (brew install cmake) and rebuild.'; exit 1; }
  mkdir -p .local
  if [ ! -d .local/piper/.git ]; then git clone https://github.com/OHF-Voice/piper1-gpl.git .local/piper; fi
  git -C .local/piper checkout "$REV"
  cmake -S .local/piper/libpiper -B .local/piper-build -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DCMAKE_INSTALL_PREFIX="$ROOT/.local/runtime"
  cmake --build .local/piper-build -j 6
  cmake --install .local/piper-build
  mkdir -p .local/runtime/licenses
  cp .local/piper/COPYING .local/runtime/licenses/Piper
  cp .local/piper-build/espeak_ng/src/espeak_ng_external/COPYING .local/runtime/licenses/espeak-ng
  cp .local/piper/libpiper/lib/onnxruntime-osx-arm64-1.22.0/LICENSE .local/runtime/licenses/ONNX-Runtime
fi
mkdir -p .local/models
BASE=https://huggingface.co/rhasspy/piper-voices/resolve/main/hy/hy_AM/gor/medium
for FILE in hy_AM-gor-medium.onnx hy_AM-gor-medium.onnx.json MODEL_CARD; do
  if [ ! -s ".local/models/$FILE" ]; then
    curl --fail --location --retry 3 "$BASE/$FILE" -o ".local/models/$FILE.part"
    mv ".local/models/$FILE.part" ".local/models/$FILE"
  fi
done
echo '1c91fc33fecbbfc6b7921f9d11fd7487a859053a3a1987147f5c361155b89e7c  .local/models/hy_AM-gor-medium.onnx
01a8458d4ff226fac1b7dc7b1f619851fdbc8a9bd09d6a604e65e304c9600c2e  .local/models/hy_AM-gor-medium.onnx.json' | shasum -a 256 --check --status
"$ROOT/script/prepare-translation.sh"
if [ -n "${TARGET_BUILD_DIR:-}" ]; then
  RES="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
  LIB="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
  mkdir -p "$RES/Models" "$RES/Licenses" "$LIB"
  cp .local/models/* "$RES/Models/"
  cp -R .local/runtime/share/espeak-ng-data "$RES/"
  cp .local/runtime/lib/libpiper.dylib .local/runtime/lib/libonnxruntime.1.22.0.dylib "$LIB/"
  cp .local/runtime/licenses/* native/licenses/* "$RES/Licenses/"
  cp LICENSE "$RES/Licenses/Armenian-Speaker-GPL-3.0"
  xattr -cr "$TARGET_BUILD_DIR/$WRAPPER_NAME"
  for DYLIB in "$LIB/"*.dylib; do codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" "$DYLIB"; done
fi
