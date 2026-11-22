#!/bin/sh
# Regenerates Tests/HLSJSGoldens.swift by running hls.js v1.7.3's own TypeScript on fixed inputs.
# Needs network (git, npm). Run by hand only: `sh submodules/HLSPlayback/Tools/hlsjs-goldens/generate.sh`.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
OUT="$HERE/../../Tests/HLSJSGoldens.swift"
EXPECTED_REVISION=e5ff3583965e3af16c4a4b4d2b5f7bd1ffb5b7de

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

git clone --quiet --depth 1 --branch v1.7.3 https://github.com/video-dev/hls.js.git "$WORK/hls.js" 2>/dev/null
REVISION=$(git -C "$WORK/hls.js" rev-parse HEAD)
if [ "$REVISION" != "$EXPECTED_REVISION" ]; then
    echo "unexpected hls.js revision $REVISION" >&2
    exit 1
fi

# The runtime packages hls.js's sources import, at the versions its package.json pins.
(cd "$WORK/hls.js" && npm install --silent --no-save --no-package-lock --ignore-scripts eventemitter3@5.0.4 url-toolkit@2.2.5 >/dev/null)

cp "$HERE/entry.ts" "$WORK/hls.js/goldens-entry.ts"
# Every constant src/define-plugin.d.ts declares.
(cd "$WORK/hls.js" && npx --yes esbuild@0.25.0 goldens-entry.ts --bundle --platform=node --format=esm --log-level=warning \
    --outfile="$WORK/goldens.mjs" \
    --define:__VERSION__='"1.7.3"' \
    --define:__USE_ALT_AUDIO__=false \
    --define:__USE_EME_DRM__=false \
    --define:__USE_SUBTITLES__=false \
    --define:__USE_CMCD__=false \
    --define:__USE_CONTENT_STEERING__=false \
    --define:__USE_VARIABLE_SUBSTITUTION__=false \
    --define:__USE_M2TS_ADVANCED_CODECS__=false \
    --define:__USE_MEDIA_CAPABILITIES__=false \
    --define:__USE_INTERSTITIALS__=false \
    --define:__USE_IFRAMES__=false \
    --define:__IN_WORKER__=false \
    --define:__HLS_WORKER_BUNDLE__=undefined)

node "$WORK/goldens.mjs" > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
echo "wrote $OUT"
