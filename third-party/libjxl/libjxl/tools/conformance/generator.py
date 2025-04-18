#!/usr/bin/env python3
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.
"""Tool for generating a conformance testing corpus from a set of .jxl files.

This is not the JPEG XL conformance test runner. This is a tool to generate a
conformance testing corpus from a set of .jxl files.
"""

import argparse
import itertools
import json
import os
import shutil
import subprocess
import sys


def GenerateConformanceCorpus(args):
    """Generate the conformance test corpus for the given arguments."""
    files = []
    for jxl in args.inputs:
        if os.path.isdir(jxl):
            # Add all the .jxl files recursively.
            for root, _, dir_files in os.walk(jxl):
                files.extend(
                    os.path.join(root, filename) for filename in dir_files
                    if filename.lower().endswith('.jxl'))
        else:
            files.append(jxl)

    os.makedirs(args.output, 0o755, exist_ok=True)

    test_ids = []
    for jxl in files:
        # Generate a unique test_id for this file based on the filename.
        test_id = os.path.basename(jxl).lower()
        if test_id.endswith('.jxl'):
            test_id = test_id[:-4]
        if test_id in test_ids:
            for i in itertools.count(2):
                candidate = test_id + '%02d' % i
                if candidate not in test_ids:
                    test_id = candidate
                    break
        test_ids.append(test_id)

        test_dir = os.path.join(args.output, test_id)
        os.makedirs(test_dir, 0o755, exist_ok=True)
        print('Generating %s' % (test_id, ))
        input_file = os.path.join(test_dir, 'input.jxl')
        shutil.copy(jxl, input_file)

        # The test descriptor file.
        descriptor = {}
        descriptor['jxl'] = 'input.jxl'

        original_icc_filename = os.path.join(test_dir, 'original.icc')
        reconstructed_filename = os.path.join(test_dir, 'reconstructed.jpg')
        pixel_prefix = os.path.join(test_dir, 'reference')
        output_file = pixel_prefix + '_image.npy'
        cmd = [args.decoder, input_file, output_file]
        metadata_filename = os.path.join(test_dir, 'test.json')
        cmd.extend(['--metadata_out', metadata_filename])
        cmd.extend(['--icc_out', pixel_prefix + '.icc'])

        # Decode and generate the reference files.
        subprocess.check_call(cmd)

        with open(metadata_filename, 'r') as f:
            metadata = json.load(f)

        if os.path.exists(original_icc_filename):
            metadata['original_icc'] = "original.icc"

        if os.path.exists(reconstructed_filename):
            metadata['reconstructed_jpeg'] = "reconstructed.jpg"

        for frame in metadata['frames']:
            frame['rms_error'] = args.rmse
            frame['peak_error'] = args.peak_error

        if 'preview' in metadata:
            metadata['preview']['rms_error'] = args.rmse
            metadata['preview']['peak_error'] = args.peak_error

        # Create the test descriptor file.
        with open(metadata_filename, 'w') as f:
            json.dump(metadata, f, indent=2)

    # Generate a corpus descriptor with the list of the all the test_id names,
    # one per line.
    with open(os.path.join(args.output, 'corpus.txt'), 'w') as f:
        f.write(''.join(line + '\n' for line in test_ids))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--decoder',
                        metavar='DECODER',
                        required=True,
                        help='path to the decoder binary under test.')
    parser.add_argument('--output',
                        metavar='DIR',
                        required=True,
                        help='path to the output directory')
    parser.add_argument('--peak_error',
                        metavar='PEAK_ERROR',
                        type=float,
                        required=True,
                        help='peak error for each testcase')
    parser.add_argument('--rmse',
                        metavar='RMSE',
                        type=float,
                        required=True,
                        help='max RMSE for each testcase')
    parser.add_argument('inputs',
                        metavar='JXL',
                        nargs='+',
                        help='path to input .jxl file(s)')
    args = parser.parse_args()
    GenerateConformanceCorpus(args)


if __name__ == '__main__':
    main()
