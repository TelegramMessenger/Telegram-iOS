#!/usr/bin/env bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Tool to create the reference software .zip package with its required
# dependencies bundled.

set -eu

MYDIR=$(dirname $(realpath "$0"))

# Temporary files cleanup hooks.
CLEANUP_FILES=()
cleanup() {
  if [[ ${#CLEANUP_FILES[@]} -ne 0 ]]; then
    rm -fr "${CLEANUP_FILES[@]}"
  fi
}
trap 'retcode=$?; { set +x; } 2>/dev/null; cleanup' INT TERM EXIT


main() {
  # Run from the repo's top level directory.
  cd "${MYDIR[@]}/.."

  local deps=(
    third_party/brotli
    third_party/highway
    third_party/skcms
  )

  local ref_files=($(git ls-files))
  for dep in "${deps[@]}"; do
    local dep_files=($(git -C "${dep}" ls-files))
    for dep_file in "${dep_files[@]}"; do
      ref_files+=("${dep}/${dep_file}")
    done
  done

  echo "Packaging ${#ref_files[@]} files..." >&2
  local dest_zip="reference_package.zip"
  rm -f "${dest_zip}"
  printf '%s\n' "${ref_files[@]}" | zip -q -@ "${dest_zip}"

  if [[ "${1:-}" == "test" ]]; then
    echo "Testing on docker..." >&2
    set -x
    sudo docker run --rm -v "$(realpath ${dest_zip}):/home/pkg.zip:ro" \
      ubuntu:20.04 <<EOF
set -eux

apt update
DEBIAN_FRONTEND=noninteractive apt install -y build-essential zip cmake

cd /home/
unzip -q pkg.zip
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DJPEGXL_ENABLE_SJPEG=OFF ..
cmake --build . -- -j\$(nproc)

tools/djxl ../testdata/jxl/blending/cropped_traffic_light.jxl test.png
tools/cjxl ../testdata/jxl/flower/flower.png.im_q85_444.jpg test.jxl
tools/djxl test.jxl test.jpg
EOF
    set +x
  fi
  echo "${dest_zip} ready."
}

main "$@"
