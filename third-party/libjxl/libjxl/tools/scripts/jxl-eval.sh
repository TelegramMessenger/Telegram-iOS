#!/bin/bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -eu

GSROOT="${GSROOT:-gs://jxl-quality}"
URLROOT="${URLROOT:-https://storage.googleapis.com/jxl-quality}"
BUILD_DIR="${BUILD_DIR:-./build}"
BUILD_MODE="${BUILD_MODE:-opt}"
DESC="${DESC:-exp}"

build_libjxl() {
  export BUILD_DIR="${BUILD_DIR}"
  export SKIP_TEST=1
  ./ci.sh "${BUILD_MODE}"
}

build_mozjpeg() {
  if [[ ! -d "${HOME}/mozjpeg" ]]; then
    (cd "${HOME}"
     git clone https://github.com/mozilla/mozjpeg.git
    )
  fi
  (cd "${HOME}/mozjpeg"
   mkdir -p build
   cmake -GNinja -B build
   ninja -C build
  )
}

download_corpus() {
  local corpus="$1"
  local localdir="${HOME}/corpora/${corpus}"
  local remotedir="${GSROOT}/corpora/${corpus}"
  if [[ ! -d "${localdir}" ]]; then
    mkdir -p "${localdir}"
  fi
  gsutil -m rsync "${remotedir}" "${localdir}"
}

create_report() {
  local corpus="$1"
  local codec="$2"
  shift 2
  local rev="$(git rev-parse --short HEAD)"
  local originals="${URLROOT}/corpora/${corpus}"
  if git diff HEAD --quiet; then
    local expid="${corpus}/${rev}/base"
  else
    local expid="${corpus}/${rev}/${DESC}"
  fi
  local output_dir="benchmark_results/${expid}"
  local bucket="eval/${USER}/${expid}"
  local indexhtml="index.$(echo ${codec} | tr ':' '_').html"
  local url="${URLROOT}/${bucket}/${indexhtml}"
  local use_decompressed="--save_decompressed --html_report_use_decompressed"
  if [[ "${codec:0:4}" == "jpeg" ]]; then
    use_decompressed="--nohtml_report_use_decompressed"
  fi
  (
   cd "${BUILD_DIR}"
   tools/benchmark_xl \
     --output_dir "${output_dir}" \
     --input "${HOME}/corpora/${corpus}/*.??g" \
     --codec="${codec}" \
     --save_compressed \
     --write_html_report \
     "${use_decompressed}" \
     --originals_url="${originals}" \
     $@
   gsutil -m rsync "${output_dir}" "${GSROOT}/${bucket}"
   echo "You can view evaluation results at:"
   echo "${url}"
  )
}

cmd_upload_corpus() {
  local corpus="$1"
  gsutil -m rsync "${HOME}/corpora/${corpus}" "${GSROOT}/corpora/${corpus}"
}

cmd_report() {
  local corpus="$1"
  local codec="$2"
  if [[ "${codec}" == *","* ]]; then
    echo "Multiple codecs are not allowed in html report"
    exit 1
  fi
  download_corpus "${corpus}"
  if [[ "${codec:0:4}" == "jpeg" ]]; then
    build_mozjpeg
    export LD_LIBRARY_PATH="${HOME}/mozjpeg/build:${LD_LIBRARY_PATH:-}"
  fi
  build_libjxl
  create_report "$@"
}

main() {
  local cmd="${1:-}"
  if [[ -z "${cmd}" ]]; then
    cat >&2 <<EOF
Use: $0 CMD

Where CMD is one of:
 upload_corpus CORPUS
   Upload the image corpus in $HOME/corpora/CORPUS to the cloud
 report CORPUS CODEC
   Build and run benchmark of codec CODEC on image corpus CORPUS and upload
   the results to the cloud. If the codec is jpeg, the mozjpeg library will be
   built and used through LD_LIBRARY_PATH
EOF
    echo "Usage $0 CMD"
    exit 1
  fi
  cmd="cmd_${cmd}"
  shift
  set -x
  "${cmd}" "$@"
}

main "$@"
