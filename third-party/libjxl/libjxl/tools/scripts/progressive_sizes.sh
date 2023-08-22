#!/bin/bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.


set -eu

TMPDIR=$(mktemp -d)

cleanup() {
  rm -rf ${TMPDIR}
}

trap cleanup EXIT


CJXL=$(realpath $(dirname "$0"))/../../build/tools/cjxl
DJXL=$(realpath $(dirname "$0"))/../../build/tools/djxl

${CJXL} "$@" ${TMPDIR}/x.jxl &>/dev/null
S1=$(${DJXL} ${TMPDIR}/x.jxl --print_read_bytes -s 1 2>&1 | grep 'Decoded' | grep -o '[0-9]*')
S2=$(${DJXL} ${TMPDIR}/x.jxl --print_read_bytes -s 2 2>&1 | grep 'Decoded' | grep -o '[0-9]*')
S8=$(${DJXL} ${TMPDIR}/x.jxl --print_read_bytes -s 8 2>&1 | grep 'Decoded' | grep -o '[0-9]*')

echo "8x: $S8 2x: $S2 1x: $S1"
