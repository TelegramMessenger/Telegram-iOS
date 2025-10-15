#!/usr/bin/env bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -eu

MYDIR=$(dirname $(realpath "$0"))


main() {
  cd "${MYDIR}/../../../third_party"
  local zipurl
  local repourl
  for repourl in \
    'https://github.com/veluca93/IQA-optimization.git' \
    'https://github.com/Netflix/vmaf.git' \
    'https://github.com/thorfdbg/difftest_ng.git'
  do
    local reponame=$(basename "${repourl%.git}")
    local dirname=$(basename "${reponame}")
    if [[ ! -e "${dirname}" ]]; then
      git clone "${repourl}"
    fi
  done
  for zipurl in \
    'https://sourceforge.net/projects/hdrvdp/files/hdrvdp/2.2.2/hdrvdp-2.2.2.zip' \
    'https://sourceforge.net/projects/hdrvdp/files/simple_metrics/1.0/hdr_metrics.zip'
  do
    local zipfile="$(basename "${zipurl}")"
    local dirname="$(basename "${zipfile}" '.zip')"
    rm -fr "${dirname}"
    if [[ ! -e "${zipfile}" ]]; then
      wget -O "${zipfile}.tmp" "${zipurl}"
      mv "${zipfile}.tmp" "${zipfile}"
    fi
    unzip "${zipfile}" "${dirname}"/'*'
  done

  pushd hdrvdp-2.2.2
  patch -p1 < ../../tools/benchmark/metrics/hdrvdp-fixes.patch
  pushd matlabPyrTools_1.4_fixed
  mkoctfile --mex MEX/corrDn.c MEX/convolve.c MEX/wrap.c MEX/edges.c
  mkoctfile --mex MEX/pointOp.c
  mkoctfile --mex MEX/upConv.c
  popd
  popd


  pushd difftest_ng
  ./configure
  make
  popd


  pushd vmaf/libvmaf
  rm -rf build
  meson build --buildtype release
  ninja -vC build
  popd
}
main "$@"

