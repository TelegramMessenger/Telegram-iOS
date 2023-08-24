#!/usr/bin/env bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -eu
dir="$(dirname "$0")"

main() {
  local metrics=(
    HDR-VDP:"${dir}"/hdrvdp.sh
    MRSE:"${dir}"/mrse.sh
    puPSNR:"${dir}"/pupsnr.sh
    puSSIM:"${dir}"/pussim.sh
  )

  local metrics_args=$(printf '%s' "${metrics[@]/#/,}")
  metrics_args=${metrics_args:1}


  "${dir}/../../../build/tools/benchmark_xl" \
    --print_details_csv \
    --num_threads=32 \
    --error_pnorm=6 \
    --extra_metrics ${metrics_args} \
    "$@"
}

main "$@"
