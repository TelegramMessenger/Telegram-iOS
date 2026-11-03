#!/usr/bin/env bash
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

"$(dirname "$0")/run_all_sdr_metrics.sh" "$@" | sed -n '/```/q;p' > sdr_results.csv
mkdir -p sdr_plots/
rm -rf sdr_plots/*
python3 "$(dirname "$0")/plots.py" sdr_results.csv sdr_plots
