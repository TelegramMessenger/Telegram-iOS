#!/bin/bash

set -e
set -x

OUT_DIR="$1"
INCLUDE_DIR="$2"
shift
shift
LIBS="$@"

mkdir -p "$OUT_DIR/lib"

/usr/bin/lipo $LIBS -output "$OUT_DIR/lib/libcrypto.a" -create
cp -r "$INCLUDE_DIR" "$OUT_DIR/"

