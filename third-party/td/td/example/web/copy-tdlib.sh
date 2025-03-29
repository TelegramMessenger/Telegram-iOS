#!/bin/sh
cd $(dirname $0)

DEST=tdweb/src/prebuilt/release/
mkdir -p $DEST || exit 1
cp build/wasm/td_wasm.js build/wasm/td_wasm.wasm $DEST || exit 1
