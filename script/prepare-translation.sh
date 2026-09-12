#!/bin/bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export MACOSX_DEPLOYMENT_TARGET=14.0
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
RUNTIME="$ROOT/.local/translation-runtime"
if [ ! -f "$RUNTIME/lib/libctranslate2.dylib" ]; then
  if [ ! -d .local/ctranslate2 ]; then
    git clone --recurse-submodules https://github.com/OpenNMT/CTranslate2.git .local/ctranslate2
  fi
  git -C .local/ctranslate2 checkout 617405f4b050e994e829d527da6caa0e0030afe7
  git -C .local/ctranslate2 submodule update --init --recursive
  cmake -S .local/ctranslate2 -B .local/ct-build -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DBUILD_SHARED_LIBS=ON -DWITH_MKL=OFF -DWITH_DNNL=OFF -DWITH_ACCELERATE=ON -DOPENMP_RUNTIME=NONE -DWITH_RUY=ON -DBUILD_CLI=OFF -DCMAKE_INSTALL_PREFIX="$RUNTIME"
  cmake --build .local/ct-build -j 6
  cmake --install .local/ct-build
fi
if [ ! -f "$RUNTIME/lib/libsentencepiece.a" ]; then
  if [ ! -d .local/sentencepiece ]; then git clone https://github.com/google/sentencepiece.git .local/sentencepiece; fi
  git -C .local/sentencepiece checkout 31646a467d2051eb904e0b45de3a73e91fe1c1e3
  cmake -S .local/sentencepiece -B .local/sp-build -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DSPM_ENABLE_SHARED=OFF -DSPM_BUILD_TEST=OFF -DCMAKE_INSTALL_PREFIX="$RUNTIME"
  cmake --build .local/sp-build -j 6
  cmake --install .local/sp-build
fi
LIB="$RUNTIME/lib/libtranslation.dylib"
if [ ! -f "$LIB" ] || [ native/TranslationBridge.cpp -nt "$LIB" ] || [ native/TranslationBridge.h -nt "$LIB" ]; then
  xcrun clang++ -std=c++17 -O2 -arch arm64 -mmacosx-version-min=14.0 -dynamiclib native/TranslationBridge.cpp -I "$RUNTIME/include" -L "$RUNTIME/lib" -lctranslate2 -lsentencepiece -o "$LIB" -Wl,-install_name,@rpath/libtranslation.dylib -Wl,-rpath,@loader_path
fi
for PAIR in hy-ru ru-hy; do
  mkdir -p ".local/translation-models/$PAIR"
  if [ "$PAIR" = hy-ru ]; then REV=acba5e31fedae66078303fb600f6fb8a5792b8af; else REV=7f2a3f435914324124d8512d98c88cfacacc8437; fi
  for FILE in config.json model.bin shared_vocabulary.json source.spm target.spm; do
    DEST=".local/translation-models/$PAIR/$FILE"
    if [ ! -s "$DEST" ]; then
      curl -fsSL --retry 3 "https://huggingface.co/manancode/opus-mt-$PAIR-ctranslate2-android/resolve/$REV/$FILE" -o "$DEST.part"
      mv "$DEST.part" "$DEST"
    fi
  done
done
shasum -a 256 --check --status native/translation-models.sha256
mkdir -p "$RUNTIME/licenses"
if [ -d .local/ctranslate2 ]; then
  cp .local/ctranslate2/third_party/spdlog/LICENSE "$RUNTIME/licenses/spdlog"
  cp .local/ctranslate2/third_party/ruy/third_party/cpuinfo/LICENSE "$RUNTIME/licenses/cpuinfo"
  head -15 .local/ctranslate2/include/half_float/half.hpp > "$RUNTIME/licenses/half-float"
  cp .local/ctranslate2/LICENSE "$RUNTIME/licenses/CTranslate2"
  cp .local/ctranslate2/third_party/ruy/LICENSE "$RUNTIME/licenses/Ruy"
  cp .local/ctranslate2/third_party/cpu_features/LICENSE "$RUNTIME/licenses/CPU-Features"
fi
if [ -d .local/sentencepiece ]; then
  cp .local/sentencepiece/LICENSE "$RUNTIME/licenses/SentencePiece"
  for DEP in protobuf-lite absl darts_clone esaxx; do
    cp ".local/sentencepiece/third_party/$DEP/LICENSE" "$RUNTIME/licenses/$DEP"
  done
fi
if [ -n "${TARGET_BUILD_DIR:-}" ]; then
  RES="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
  FRAMEWORKS="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
  mkdir -p "$RES/TranslationModels" "$RES/Licenses" "$FRAMEWORKS"
  cp -R .local/translation-models/* "$RES/TranslationModels/"
  cp "$RUNTIME/licenses/"* "$RES/Licenses/"
  cp "$LIB" "$FRAMEWORKS/"
  cp "$RUNTIME/lib/libctranslate2.4.6.0.dylib" "$FRAMEWORKS/libctranslate2.4.dylib"
  for FILE in "$FRAMEWORKS/libtranslation.dylib" "$FRAMEWORKS/libctranslate2.4.dylib"; do
    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" "$FILE"
  done
fi
