#!/usr/bin/env bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -eu
dir="$(dirname "$0")"

main() {
  local metrics=(
    FSIM-Y:"${dir}"/fsim-y.sh
    FSIM-RGB:"${dir}"/fsim-rgb.sh
    LPIPS:"${dir}"/lpips-rgb.sh
    MS-SSIM-Y:"${dir}"/msssim-y.sh
    NLPD:"${dir}"/nlpd-y.sh
    SSIMULACRA:"${dir}"/ssimulacra.sh
    VIF:"${dir}"/vif-rgb.sh
    VMAF:"${dir}"/vmaf.sh
  )
  # other metrics, not in core experiments:
#    VSI:"${dir}"/vsi-rgb.sh
#    SSIM-RGB:"${dir}"/ssim-rgb.sh
#    SSIM-Y:"${dir}"/ssim-y.sh
#    GMSD:"${dir}"/gmsd.sh
#    DISTS:"${dir}"/dists-rgb.sh
#    MS-SSIM-RGB:"${dir}"/msssim-rgb.sh

  local metrics_args=$(printf '%s' "${metrics[@]/#/,}")
  metrics_args=${metrics_args:1}


  "${dir}/../../../build/tools/benchmark_xl" \
    --print_details_csv \
    --num_threads=1 \
    --error_pnorm=6 \
    --extra_metrics ${metrics_args} \
    "$@"
}

main "$@"
