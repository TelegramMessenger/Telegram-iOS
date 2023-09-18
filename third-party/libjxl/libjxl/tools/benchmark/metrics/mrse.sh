#!/usr/bin/env bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -euo pipefail

original="$1"
decoded="$2"
output="$3"
intensity_target="$4"

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

"$(dirname "$0")"/../../../third_party/difftest_ng/difftest_ng --mrse "$linearized_original" "$linearized_decoded" \
  | sed -e 's/^MRSE:\s*//' \
  > "$output"
