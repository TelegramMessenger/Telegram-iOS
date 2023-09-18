#!/usr/bin/env bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

./compute_octave_metric.sh "$@" \
  --path "$(dirname "$0")"/../../../third_party/hdr_metrics/ \
  "$(dirname "$0")"/compute-pumetrics.m 'ssim'
