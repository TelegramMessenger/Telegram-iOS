#!/bin/bash
# Сборка TgApiFix.dylib — выполнять на Mac с установленным Xcode.
# На выходе: TgApiFix.dylib (arm64, ad-hoc подпись).
set -e
cd "$(dirname "$0")"
xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=13.0 \
  -dynamiclib -framework Foundation -framework UIKit \
  -o TgApiFix.dylib TgApiFix.m
codesign --force --sign - TgApiFix.dylib
echo "OK: $(pwd)/TgApiFix.dylib"
