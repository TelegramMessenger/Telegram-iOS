#!/bin/bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Produces a demo video showing VarDCT block type selection
# from very high quality to very low quality.

# Assumes ImageMagick convert, ffmpeg, bc are available.

set -eu

MYDIR=$(dirname $(realpath "$0"))

CLEANUP_FILES=()
cleanup() {
  if [[ ${#CLEANUP_FILES[@]} -ne 0 ]]; then
    rm -fr "${CLEANUP_FILES[@]}"
  fi
}
trap "{ set +x; } 2>/dev/null; cleanup" INT TERM EXIT



main() {
  local infile="${1:-}"
  if [[ -z "${infile}" ]]; then
    cat >&2 <<EOF
Use: $0 IMAGE [OUT.apng]

Where IMAGE is an input image and OUT.apng is the output
EOF
    exit 1
  fi

  shift

  local outfile="$@"
  if [[ -z "${outfile}" ]]; then
    # default output filename
    outfile=vardct-select-demo.apng
  fi

  if ! command -v benchmark_xl &>/dev/null 2>&1; then
    PATH=$PATH:$MYDIR/../build/tools
    if ! command -v benchmark_xl &>/dev/null 2>&1; then
      echo "Could not find benchmark_xl, try building first"
      exit
    fi
  fi
  local b=benchmark_xl

  if ! command -v ffmpeg &>/dev/null 2>&1; then
    echo "Could not find ffmpeg"
    exit
  fi

  if ! command -v convert &>/dev/null 2>&1; then
    echo "Could not find ImageMagick (convert)"
    exit
  fi

  local tmp=$(mktemp -d --suffix=vardctdemo)
  CLEANUP_FILES+=("${tmp}")

  cp $infile $tmp/orig

  local n=0
  local pixels="$(identify -format "(%w * %h)" $tmp/orig)"
  for i in $(seq 0.2 0.2 2) $(seq 2.5 0.5 5) $(seq 6 1 10) $(seq 12 2 40); do
    $b --input=$tmp/orig --codec=jxl:d$i --save_decompressed --save_compressed \
      --debug_image_dir=$tmp --output_dir=$tmp
    convert $tmp/orig \( $tmp/orig.jxl:d$i.dbg/ac_strategy.png \
      -alpha set -channel A -evaluate set 66% \) \
      -composite $tmp/t.ppm
    bytes=$(stat -c "%s" $tmp/orig.jxl_d$i)
    bpp=$( echo "$bytes * 8 / $pixels " | bc -l | cut -b 1-6 )
    label="cjxl -d $i  ($((bytes / 1000)) kb, bpp: $bpp)"
    convert +append $tmp/t.ppm $tmp/orig.jxl_d$i.png $tmp/t2.ppm
    convert $tmp/t2.ppm \
          -gravity north \
          -pointsize 32 \
          -stroke '#000C' -strokewidth 5 -annotate +0+12 "$label" \
          -stroke  none   -fill white    -annotate +0+12 "$label" $tmp/frame-$n.png

    n=$((n+1))
  done

  ffmpeg -framerate 1 -i $tmp/frame-%d.png $outfile
}

main "$@"
