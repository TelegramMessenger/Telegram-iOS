#!/usr/bin/env bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Usage: ./compute-octave-metric.sh <original> <decoded> <output> <intensity_target> [octave args...]
# Where octave args do not need to contain -qf or the path to the original and decoded images.

set -euo pipefail

original="$1"
decoded="$2"
output="$3"
intensity_target="$4"
shift 4

tmpdir="$(mktemp --directory)"

linearized_original="$(mktemp --tmpdir="$tmpdir" --suffix='.pfm')"
linearized_decoded="$(mktemp --tmpdir="$tmpdir" --suffix='.pfm')"

cleanup() {
  rm -- "$linearized_original" "$linearized_decoded"
  rmdir --ignore-fail-on-non-empty -- "$tmpdir"
}
trap cleanup EXIT

linearize() {
  local input="$1"
  local output="$2"
  convert "$input" -set colorspace sRGB -colorspace RGB -evaluate multiply "$intensity_target" "$output"
}

linearize "$original" "$linearized_original"
linearize "$decoded" "$linearized_decoded"

octave -qf "$@" \
  "$linearized_original" "$linearized_decoded" \
  2> /dev/null \
  > "$output"
