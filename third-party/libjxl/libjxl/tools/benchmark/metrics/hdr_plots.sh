#!/usr/bin/env bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

"$(dirname "$0")/run_all_hdr_metrics.sh" "$@" | sed -n '/```/q;p' > hdr_results.csv
mkdir -p hdr_plots/
rm -rf hdr_plots/*
python3 "$(dirname "$0")/plots.py" hdr_results.csv hdr_plots
