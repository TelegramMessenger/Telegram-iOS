#!/bin/sh
# Public synthetic fixtures only. Requires an existing FFmpeg installation.
# Send as files (without client-side re-encoding) to preserve the track matrix.
set -eu
out=${1:?Usage: generate-rotation-fixtures.sh OUTPUT_DIRECTORY}
mkdir -p "$out"
scratch=$(mktemp -d)
trap 'rm -f "$scratch/sideways.mp4"; rmdir "$scratch"' EXIT
ffmpeg -nostdin -v error -n -f lavfi -i 'testsrc2=size=272x480:rate=30' \
    -t 3 -vf transpose=cclock -c:v libx264 -pix_fmt yuv420p \
    "$scratch/sideways.mp4"
ffmpeg -nostdin -v error -n -display_rotation -90 -i "$scratch/sideways.mp4" \
    -c copy -movflags +faststart "$out/portrait-display-matrix-minus90.mp4"
ffmpeg -nostdin -v error -n -f lavfi -i 'testsrc2=size=480x272:rate=30' \
    -t 3 -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
    "$out/landscape-no-rotation.mp4"
ffmpeg -nostdin -v error -n -f lavfi -i 'testsrc2=size=272x480:rate=30' \
    -t 3 -c:v libx264 -pix_fmt yuv420p -movflags +faststart \
    "$out/portrait-no-rotation.mp4"
