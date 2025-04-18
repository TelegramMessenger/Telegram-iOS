#!/usr/bin/env bash

# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -euo pipefail

encoder="$(dirname "$0")"/TAppEncoderHighBitDepthStatic
cfg_dir="$(dirname "$0")"/../../../third_party/HEVCSoftware/cfg

usage() {
  echo "$0 [-v] [-q <N>] <input.png> <output.bin>" >&2
  exit 1
}

q=27
verbose=0

while getopts ':hq:v' arg; do
  case "$arg" in
    h)
      usage
      ;;

    q)
      q="$OPTARG"
      ;;

    v)
      verbose=1
      ;;

    \?)
      echo "Unrecognized option -$OPTARG" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND-1))

if [ $# -lt 2 ]; then
  usage
fi

run() {
  if [ "$verbose" -eq 1 ]; then
    "$@"
  else
    "$@" > /dev/null 2>&1
  fi
}

input="$1"
output="$2"

yuv="$(mktemp)"
bin="$(mktemp)"

to_clean=("$yuv" "$bin")
cleanup() {
  rm -- "${to_clean[@]}"
}
trap cleanup EXIT

run ffmpeg -hide_banner -i "$input" -pix_fmt yuv444p10le -vf scale=out_color_matrix=bt709 -color_primaries bt709 -color_trc bt709 -colorspace bt709 -f rawvideo -y "$yuv"

width="$(identify -format '%w' "$input")"
height="$(identify -format '%h' "$input")"

start="$EPOCHREALTIME"
run "$encoder" -c "$cfg_dir"/encoder_intra_main_scc_10.cfg -f 1 -fr 1 -wdt "$width" -hgt "$height" --InputChromaFormat=444 --InputBitDepth=10 --ConformanceWindowMode=1 -i "$yuv" -b "$bin" -q "$q"
end="$EPOCHREALTIME"

elapsed="$(echo "$end - $start" | bc)"
run echo "Completed in $elapsed seconds"

echo "$elapsed" > "${output%.bin}".time

icc="${output%.*}.icc"
if run convert "$input" "$icc"; then
  to_clean+=("$icc")
fi

pack_program="$(cat <<'END'
  use File::Copy;
  use IO::Handle;
  my ($width, $height, $bin, $icc, $output) = @ARGV;
  open my $output_fh, '>:raw', $output;
  syswrite $output_fh, pack 'NN', $width, $height;
  syswrite $output_fh, pack 'N', -s $icc;
  copy $icc, $output_fh;
  copy $bin, $output_fh;
END
)"
run perl -Mstrict -Mwarnings -Mautodie -e "$pack_program" -- "$width" "$height" "$bin" "$icc" "$output"
