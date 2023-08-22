#!/bin/bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# End-to-end roundtrip tests for cjpegli and djpegli tools, and other linux
# tools linked with the jpegli library.

set -eux

MYDIR=$(dirname $(realpath "$0"))
JPEGXL_TEST_DATA_PATH="${MYDIR}/../../testdata"

# Temporary files cleanup hooks.
CLEANUP_FILES=()
cleanup() {
  if [[ ${#CLEANUP_FILES[@]} -ne 0 ]]; then
    rm -rf "${CLEANUP_FILES[@]}"
  fi
}
trap 'retcode=$?; { set +x; } 2>/dev/null; cleanup' INT TERM EXIT

verify_ssimulacra2() {
  local score="$("${ssimulacra2}" "${1}" "${2}")"
  python3 -c "import sys; sys.exit(not ${score} >= ${3})"
}

verify_max_bpp() {
  local infn="$1"
  local jpgfn="$2"
  local maxbpp="$3"
  local size="$(wc -c "${jpgfn}" | cut -d' ' -f1)"
  local pixels=$(( "$(identify "${infn}" | cut -d' ' -f3 | tr 'x' '*')" ))
  python3 -c "import sys; sys.exit(not ${size} * 8 <= ${maxbpp} * ${pixels})"
}

# Test that jpeg files created with cjpegli can be decoded with normal djpeg.
cjpegli_test() {
  local infn="${JPEGXL_TEST_DATA_PATH}/$1"
  local encargs="$2"
  local minscore="$3"
  local maxbpp="$4"
  local jpgfn="$(mktemp -p "${tmpdir}")"
  local outfn="$(mktemp -p "${tmpdir}").ppm"

  "${cjpegli}" "${infn}" "${jpgfn}" $encargs
  djpeg -outfile "${outfn}" "${jpgfn}"

  verify_ssimulacra2 "${infn}" "${outfn}" "${minscore}"
  verify_max_bpp "${infn}" "${jpgfn}" "${maxbpp}"
}

# Test full cjpegli/djpegli roundtrip.
cjpegli_djpegli_test() {
  local infn="${JPEGXL_TEST_DATA_PATH}/$1"
  local encargs="$2"
  local minscore="$3"
  local maxbpp="$4"
  local jpgfn="$(mktemp -p "${tmpdir}")"
  local outfn="$(mktemp -p "${tmpdir}").png"

  "${cjpegli}" "${infn}" "${jpgfn}" $encargs
  "${djpegli}" "${jpgfn}" "${outfn}"

  verify_ssimulacra2 "${infn}" "${outfn}" "${minscore}"
  verify_max_bpp "${infn}" "${jpgfn}" "${maxbpp}"
}

# Test the --target_size command line argument of cjpegli.
cjpegli_test_target_size() {
  local infn="${JPEGXL_TEST_DATA_PATH}/$1"
  local encargs="$2"
  local target_size="$3"
  local jpgfn="$(mktemp -p "$tmpdir")"

  "${cjpegli}" "${infn}" "${jpgfn}" $encargs --target_size "${target_size}"
  local size="$(wc -c "${jpgfn}" | cut -d' ' -f1)"
  python3 -c "import sys; sys.exit(not ${target_size} * 0.996 <= ${size})"
  python3 -c "import sys; sys.exit(not ${target_size} * 1.004 >= ${size})"
}

# Test that jpeg files created with cjpeg binary + jpegli library can be decoded
# with normal libjpeg.
cjpeg_test() {
  local infn="${JPEGXL_TEST_DATA_PATH}/$1"
  local encargs="$2"
  local minscore="$3"
  local maxbpp="$4"
  local jpgfn="$(mktemp -p "$tmpdir")"
  local outfn="$(mktemp -p "${tmpdir}").png"

  LD_LIBRARY_PATH="${build_dir}/lib/jpegli:${LD_LIBRARY_PATH:-}" \
    cjpeg $encargs -outfile "${jpgfn}" "${infn}"
  djpeg -outfile "${outfn}" "${jpgfn}"

  verify_ssimulacra2 "${infn}" "${outfn}" "${minscore}"
  verify_max_bpp "${infn}" "${jpgfn}" "${maxbpp}"
}

# Test decoding of jpeg files with the djpegli binary.
djpegli_test() {
  local infn="${JPEGXL_TEST_DATA_PATH}/$1"
  local encargs="$2"
  local minscore="$3"
  local jpgfn="$(mktemp -p "$tmpdir")"

  cjpeg $encargs -outfile "${jpgfn}" "${infn}"

  # Test that disabling output works.
  "${djpegli}" "${jpgfn}" --disable_output
  for ext in png pgm ppm pfm pnm baz; do
    "${djpegli}" "${jpgfn}" /foo/bar.$ext --disable_output
  done

  # Test decoding to PNG, PPM, PNM, PFM
  for ext in png ppm pnm pfm; do
    local outfn="$(mktemp -p "${tmpdir}").${ext}"
    "${djpegli}" "${jpgfn}" "${outfn}" --num_reps 2
    verify_ssimulacra2 "${infn}" "${outfn}" "${minscore}"
  done

  # Test decoding to PGM (for grayscale input)
  if [[ "${infn: -6}" == ".g.png" ]]; then
    local outfn="$(mktemp -p "${tmpdir}").pgm"
    "${djpegli}" "${jpgfn}" "${outfn}" --quiet
    verify_ssimulacra2 "${infn}" "${outfn}" "${minscore}"
  fi

  # Test decoding to 16 bit
  for ext in png pnm; do
    local outfn8="$(mktemp -p "${tmpdir}").8.${ext}"
    local outfn16="$(mktemp -p "${tmpdir}").16.${ext}"
    "${djpegli}" "${jpgfn}" "${outfn8}"
    "${djpegli}" "${jpgfn}" "${outfn16}" --bitdepth 16
    local score8="$("${ssimulacra2}" "${infn}" "${outfn8}")"
    local score16="$("${ssimulacra2}" "${infn}" "${outfn16}")"
    python3 -c "import sys; sys.exit(not ${score16} > ${score8})"
  done
}

# Test decoding of jpeg files with the djpeg binary + jpegli library.
djpeg_test() {
  local infn="${JPEGXL_TEST_DATA_PATH}/$1"
  local encargs="$2"
  local minscore="$3"
  local jpgfn="$(mktemp -p "$tmpdir")"

  cjpeg $encargs -outfile "${jpgfn}" "${infn}"

  # Test default behaviour.
  local outfn="$(mktemp -p "${tmpdir}").pnm"
  LD_LIBRARY_PATH="${build_dir}/lib/jpegli:${LD_LIBRARY_PATH:-}" \
    djpeg -outfile "${outfn}" "${jpgfn}"
  verify_ssimulacra2 "${infn}" "${outfn}" "${minscore}"

  # Test color quantization.
  local outfn="$(mktemp -p "${tmpdir}").pnm"
  LD_LIBRARY_PATH="${build_dir}/lib/jpegli:${LD_LIBRARY_PATH:-}" \
    djpeg -outfile "${outfn}" -colors 128 "${jpgfn}"
  verify_ssimulacra2 "${infn}" "${outfn}" 48

  local outfn="$(mktemp -p "${tmpdir}").pnm"
  LD_LIBRARY_PATH="${build_dir}/lib/jpegli:${LD_LIBRARY_PATH:-}" \
    djpeg -outfile "${outfn}" -colors 128 -onepass -dither fs "${jpgfn}"
  verify_ssimulacra2 "${infn}" "${outfn}" 30

  local outfn="$(mktemp -p "${tmpdir}").pnm"
  LD_LIBRARY_PATH="${build_dir}/lib/jpegli:${LD_LIBRARY_PATH:-}" \
    djpeg -outfile "${outfn}" -colors 128 -onepass -dither ordered "${jpgfn}"
  verify_ssimulacra2 "${infn}" "${outfn}" 30

  # Test -grayscale flag.
  local outfn="$(mktemp -p "${tmpdir}").pgm"
  LD_LIBRARY_PATH="${build_dir}/lib/jpegli:${LD_LIBRARY_PATH:-}" \
    djpeg -outfile "${outfn}" -grayscale "${jpgfn}"
  local outfn2="$(mktemp -p "${tmpdir}").pgm"
  convert "${infn}" -set colorspace Gray "${outfn2}"
  # JPEG color conversion is in gamma-compressed space, so it will not match
  # the correct grayscale version very well.
  verify_ssimulacra2 "${outfn2}" "${outfn}" 60

  # Test -rgb flag.
  local outfn="$(mktemp -p "${tmpdir}").ppm"
  LD_LIBRARY_PATH="${build_dir}/lib/jpegli:${LD_LIBRARY_PATH:-}" \
    djpeg -outfile "${outfn}" -rgb "${jpgfn}"
  verify_ssimulacra2 "${infn}" "${outfn}" "${minscore}"

  # Test -crop flag.
  for geometry in 256x256+128+128 256x127+128+117; do
    local outfn="$(mktemp -p "${tmpdir}").pnm"
    LD_LIBRARY_PATH="${build_dir}/lib/jpegli:${LD_LIBRARY_PATH:-}" \
      djpeg -outfile "${outfn}" -crop "${geometry}" "${jpgfn}"
    local outfn2="$(mktemp -p "${tmpdir}").pnm"
    convert "${infn}" -crop "${geometry}" "${outfn2}"
    verify_ssimulacra2 "${outfn2}" "${outfn}" "${minscore}"
  done

  # Test output scaling.
  for scale in 1/4 3/8 1/2 5/8 9/8; do
    local scalepct="$(python3 -c "print(100.0*${scale})")%"
    local geometry=96x128+0+0
    local outfn="$(mktemp -p "${tmpdir}").pnm"
    LD_LIBRARY_PATH="${build_dir}/lib/jpegli:${LD_LIBRARY_PATH:-}" \
      djpeg -outfile "${outfn}" -scale "${scale}" -crop "${geometry}" "${jpgfn}"
    local outfn2="$(mktemp -p "${tmpdir}").pnm"
    convert "${infn}" -scale "${scalepct}" -crop "${geometry}" "${outfn2}"
    verify_ssimulacra2 "${outfn2}" "${outfn}" 80
  done
}

main() {
  local tmpdir=$(mktemp -d)
  CLEANUP_FILES+=("${tmpdir}")

  local build_dir="${1:-}"
  if [[ -z "${build_dir}" ]]; then
    build_dir=$(realpath "${MYDIR}/../../build")
  fi

  local cjpegli="${build_dir}/tools/cjpegli"
  local djpegli="${build_dir}/tools/djpegli"
  local ssimulacra2="${build_dir}/tools/ssimulacra2"
  local rgb_in="jxl/flower/flower_small.rgb.png"
  local gray_in="jxl/flower/flower_small.g.png"
  local ppm_rgb="jxl/flower/flower_small.rgb.depth8.ppm"
  local ppm_gray="jxl/flower/flower_small.g.depth8.pgm"

  cjpegli_test "${rgb_in}" "" 88.5 1.7
  cjpegli_test "${rgb_in}" "-q 80" 84 1.2
  cjpegli_test "${rgb_in}" "-q 95" 91.5 2.4
  cjpegli_test "${rgb_in}" "-d 0.5" 92 2.6
  cjpegli_test "${rgb_in}" "--chroma_subsampling 420" 87 1.5
  cjpegli_test "${rgb_in}" "--chroma_subsampling 440" 87 1.6
  cjpegli_test "${rgb_in}" "--chroma_subsampling 422" 87 1.6
  cjpegli_test "${rgb_in}" "--std_quant" 91 2.2
  cjpegli_test "${rgb_in}" "--noadaptive_quantization" 88.5 1.85
  cjpegli_test "${rgb_in}" "-p 1" 88.5 1.72
  cjpegli_test "${rgb_in}" "-p 0" 88.5 1.75
  cjpegli_test "${rgb_in}" "-p 0 --fixed_code" 88.5 1.8
  cjpegli_test "${gray_in}" "" 92 1.4

  cjpegli_test_target_size "${rgb_in}" "" 10000
  cjpegli_test_target_size "${rgb_in}" "" 50000
  cjpegli_test_target_size "${rgb_in}" "" 100000
  cjpegli_test_target_size "${rgb_in}" "--chroma_subsampling 420" 20000
  cjpegli_test_target_size "${rgb_in}" "--xyb" 20000
  cjpegli_test_target_size "${rgb_in}" "-p 0 --fixed_code" 20000

  cjpegli_test "jxl/flower/flower_small.rgb.depth8.ppm" "" 88.5 1.7
  cjpegli_test "jxl/flower/flower_small.rgb.depth16.ppm" "" 89 1.7
  cjpegli_test "jxl/flower/flower_small.g.depth8.pgm" "" 89 1.7
  cjpegli_test "jxl/flower/flower_small.g.depth16.pgm" "" 89 1.7

  cjpegli_djpegli_test "${rgb_in}" "" 89 1.7
  cjpegli_djpegli_test "${rgb_in}" "--xyb" 87 1.5

  djpegli_test "${ppm_rgb}" "-q 95" 92
  djpegli_test "${ppm_rgb}" "-q 95 -sample 1x1" 93
  djpegli_test "${ppm_gray}" "-q 95 -gray" 94

  cjpeg_test "${ppm_rgb}" "" 89 1.9
  cjpeg_test "${ppm_rgb}" "-optimize" 89 1.85
  cjpeg_test "${ppm_rgb}" "-optimize -progressive" 89 1.8
  cjpeg_test "${ppm_rgb}" "-sample 2x2" 87 1.65
  cjpeg_test "${ppm_rgb}" "-sample 1x2" 88 1.75
  cjpeg_test "${ppm_rgb}" "-sample 2x1" 88 1.75
  cjpeg_test "${ppm_rgb}" "-grayscale" -50 1.45
  cjpeg_test "${ppm_rgb}" "-rgb" 92 4.5
  cjpeg_test "${ppm_rgb}" "-restart 1" 89 1.9
  cjpeg_test "${ppm_rgb}" "-restart 1024B" 89 1.9
  cjpeg_test "${ppm_rgb}" "-smooth 30" 88 1.75
  cjpeg_test "${ppm_gray}" "-grayscale" 92 1.45
  # The -q option works differently on v62 vs. v8 cjpeg binaries, so we have to
  # have looser bounds than would be necessary if we sticked to a particular
  # cjpeg version.
  cjpeg_test "${ppm_rgb}" "-q 50" 76 0.95
  cjpeg_test "${ppm_rgb}" "-q 80" 84 1.6
  cjpeg_test "${ppm_rgb}" "-q 90" 89 2.35
  cjpeg_test "${ppm_rgb}" "-q 100" 95 7.45

  djpeg_test "${ppm_rgb}" "-q 95" 92
  djpeg_test "${ppm_rgb}" "-q 95 -sample 1x1" 93
  djpeg_test "${ppm_gray}" "-q 95 -gray" 94
}

main "$@"
