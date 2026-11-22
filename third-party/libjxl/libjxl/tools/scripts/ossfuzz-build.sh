#!/usr/bin/env bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Helper builder file to replace the /src/build.sh one in oss-fuzz/

if [[ -z "${FUZZING_ENGINE:-}" ]]; then
  echo "Don't call this script directly. Use ./ci.sh ossfuzz_* commands" \
    "instead." >&2
  exit 1
fi

set -eux

main() {
  # Build the fuzzers in release mode but force the inclusion of JXL_DASSERT()
  # checks.
  build_args=(
    -G Ninja
    -DBUILD_TESTING=OFF
    -DJPEGXL_ENABLE_BENCHMARK=OFF
    -DJPEGXL_ENABLE_DEVTOOLS=ON
    -DJPEGXL_ENABLE_EXAMPLES=OFF
    -DJPEGXL_ENABLE_FUZZERS=ON
    -DJPEGXL_ENABLE_MANPAGES=OFF
    -DJPEGXL_ENABLE_SJPEG=OFF
    -DJPEGXL_ENABLE_VIEWERS=OFF
    -DCMAKE_BUILD_TYPE=Release
  )
  export CXXFLAGS="${CXXFLAGS} -DJXL_IS_DEBUG_BUILD=1"

  mkdir -p ${WORK}
  cd ${WORK}
  cmake \
    "${build_args[@]}" \
    -DJPEGXL_FUZZER_LINK_FLAGS="${LIB_FUZZING_ENGINE}" \
    "${SRC}/libjxl"

  fuzzers=(
    color_encoding_fuzzer
    djxl_fuzzer
    fields_fuzzer
    icc_codec_fuzzer
    rans_fuzzer
    transforms_fuzzer
  )
  if [[ -n "${JPEGXL_EXTRA_ARGS:-}" ]]; then
    # Extra arguments passed to ci.sh ossfuzz commands are treated as ninja
    # targets. The environment variable is split into individual targets here,
    # which might break if passing paths with spaces, which is an unlikely use
    # case.
    fuzzers=(${JPEGXL_EXTRA_ARGS})
    echo "Building with targets: ${JPEGXL_EXTRA_ARGS}"
  fi
  ninja "${fuzzers[@]}"
}

# Build as the regular user if not already running as that user. This avoids
# having root files in the build directory.
if [[ -n "${JPEGXL_UID:-}" && "${JPEGXL_UID}" != $(id -u) ]]; then
  userspec="${JPEGXL_UID}:${JPEGXL_GID}"
  unset JPEGXL_UID
  unset JPEGXL_GID
  chroot --skip-chdir --userspec="${userspec}" \
    / $(realpath "$0") "$@"
  exit $?
fi

main "$@"
