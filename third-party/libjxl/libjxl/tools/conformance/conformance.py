#!/usr/bin/env python3
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.
"""JPEG XL conformance test runner.

Tool to perform a conformance test for a decoder.
"""

import argparse
import json
import numpy
import os
import shutil
import subprocess
import sys
import tempfile

import lcms2

def Failure(message):
    print(f"\033[91m{message}\033[0m", flush=True)
    return False

def CompareNPY(ref, ref_icc, dec, dec_icc, frame_idx, rmse_limit, peak_error):
    """Compare a decoded numpy against the reference one."""
    if ref.shape != dec.shape:
        return Failure(f'Expected shape {ref.shape} but found {dec.shape}')
    ref_frame = ref[frame_idx]
    dec_frame = dec[frame_idx]
    num_channels = ref_frame.shape[2]

    if ref_icc != dec_icc:
        # Transform colors before comparison.
        if num_channels < 3:
            return Failure(f"Only RGB images are supported")
        dec_clr = dec_frame[:, :, 0:3]
        dec_frame[:, :, 0:3] = lcms2.convert_pixels(dec_icc, ref_icc, dec_clr)

    error = numpy.abs(ref_frame - dec_frame)
    actual_peak_error = error.max()
    error_by_channel = [error[:, :, ch] for ch in range(num_channels)]
    actual_rmses = [numpy.sqrt(numpy.mean(error_ch * error_ch)) for error_ch in error_by_channel]
    actual_rmse = max(actual_rmses)

    print(f"RMSE: {actual_rmses}, peak error: {actual_peak_error}", flush=True)

    if actual_rmse > rmse_limit:
        return Failure(f"RMSE too large: {actual_rmse} > {rmse_limit}")

    if actual_peak_error > peak_error:
        return Failure(
            f"Peak error too large: {actual_peak_error} > {peak_error}")
    return True


def CompareBinaries(ref_bin, dec_bin):
    """Compare a decoded binary file against the reference for exact contents."""
    with open(ref_bin, 'rb') as reff:
        ref_data = reff.read()

    with open(dec_bin, 'rb') as decf:
        dec_data = decf.read()

    if ref_data != dec_data:
        return Failure(
            f'Binary files mismatch: {ref_bin} {dec_bin}')
    return True


TEST_KEYS = set(
    ['reconstructed_jpeg', 'original_icc', 'rms_error', 'peak_error'])


def CheckMeta(dec, ref):
    if isinstance(ref, dict):
        if not isinstance(dec, dict):
            return Failure("Malformed metadata file")
        for k, v in ref.items():
            if k in TEST_KEYS:
                continue
            if k not in dec:
                return Failure(
                    f"Malformed metadata file: key {k} not found")
            vv = dec[k]
            return CheckMeta(vv, v)
    elif isinstance(ref, list):
        if not isinstance(dec, list) or len(dec) != len(ref):
            return Failure("Malformed metadata file")
        for vv, v in zip(dec, ref):
            return CheckMeta(vv, v)
    elif isinstance(ref, float):
        if not isinstance(dec, float):
            return Failure("Malformed metadata file")
        if abs(dec - ref) > 0.0001:
            return Failure(
                f"Metadata: Expected {ref}, found {dec}")
    elif dec != ref:
        return Failure(f"Metadata: Expected {ref}, found {dec}")
    return True


def ConformanceTestRunner(args):
    ok = True
    # We can pass either the .txt file or the directory which defaults to the
    # full corpus. This is useful to run a subset of the corpus in other .txt
    # files.
    if os.path.isdir(args.corpus):
        corpus_dir = args.corpus
        corpus_txt = os.path.join(args.corpus, 'corpus.txt')
    else:
        corpus_dir = os.path.dirname(args.corpus)
        corpus_txt = args.corpus

    with open(corpus_txt, 'r') as f:
        for test_id in f:
            test_id = test_id.rstrip('\n')
            print(f"\033[94m\033[1mTesting {test_id}\033[0m", flush=True)
            test_dir = os.path.join(corpus_dir, test_id)

            with open(os.path.join(test_dir, 'test.json'), 'r') as f:
                descriptor = json.load(f)
                if 'sha256sums' in descriptor:
                    del descriptor['sha256sums']

            exact_tests = []

            with tempfile.TemporaryDirectory(prefix=test_id) as work_dir:
                input_filename = os.path.join(test_dir, 'input.jxl')
                pixel_prefix = os.path.join(work_dir, 'decoded')
                output_filename = pixel_prefix + '_image.npy'
                cmd = [args.decoder, input_filename, output_filename]
                cmd_jpeg = []
                if 'preview' in descriptor:
                    preview_filename = os.path.join(work_dir,
                                                    'decoded_preview.npy')
                    cmd.extend(['--preview_out', preview_filename])
                if 'reconstructed_jpeg' in descriptor:
                    jpeg_filename = os.path.join(work_dir, 'reconstructed.jpg')
                    cmd_jpeg = [args.decoder, input_filename, jpeg_filename]
                    exact_tests.append(('reconstructed.jpg', jpeg_filename))
                if 'original_icc' in descriptor:
                    decoded_original_icc = os.path.join(
                        work_dir, 'decoded_org.icc')
                    cmd.extend(['--orig_icc_out', decoded_original_icc])
                    exact_tests.append(('original.icc', decoded_original_icc))
                meta_filename = os.path.join(work_dir, 'meta.json')
                cmd.extend(['--metadata_out', meta_filename])
                cmd.extend(['--icc_out', pixel_prefix + '.icc'])
                cmd.extend(['--norender_spotcolors'])

                print(f"Running: {cmd}", flush=True)
                if subprocess.call(cmd) != 0:
                    ok = Failure('Running the decoder (%s) returned error' %
                                 ' '.join(cmd))
                    continue
                if cmd_jpeg:
                    print(f"Running: {cmd_jpeg}", flush=True)
                    if subprocess.call(cmd_jpeg) != 0:
                        ok = Failure(
                            'Running the decoder (%s) returned error' %
                            ' '.join(cmd_jpeg))
                        continue

                # Run validation of exact files.
                for reference_basename, decoded_filename in exact_tests:
                    reference_filename = os.path.join(test_dir,
                                                      reference_basename)
                    binary_ok = CompareBinaries(reference_filename,
                                                decoded_filename)
                    if not binary_ok and args.update_on_failure:
                        os.unlink(reference_filename)
                        shutil.copy2(decoded_filename, reference_filename)
                        binary_ok = True
                    ok = ok & binary_ok

                # Validate metadata.
                with open(meta_filename, 'r') as f:
                    meta = json.load(f)

                ok = ok & CheckMeta(meta, descriptor)

                # Pixel data.
                decoded_icc = pixel_prefix + '.icc'
                with open(decoded_icc, 'rb') as f:
                    decoded_icc = f.read()
                reference_icc = os.path.join(test_dir, "reference.icc")
                with open(reference_icc, 'rb') as f:
                    reference_icc = f.read()

                reference_npy_fn = os.path.join(test_dir, 'reference_image.npy')
                decoded_npy_fn = os.path.join(work_dir, 'decoded_image.npy')

                if not os.path.exists(decoded_npy_fn):
                    ok = Failure('File not decoded: decoded_image.npy')
                    continue

                reference_npy = numpy.load(reference_npy_fn)
                decoded_npy = numpy.load(decoded_npy_fn)

                frames_ok = True
                for i, fd in enumerate(descriptor['frames']):
                    frames_ok = frames_ok & CompareNPY(
                        reference_npy, reference_icc, decoded_npy,
                        decoded_icc, i, fd['rms_error'],
                        fd['peak_error'])

                if not frames_ok and args.update_on_failure:
                    os.unlink(reference_npy_fn)
                    shutil.copy2(decoded_npy_fn, reference_npy_fn)
                    frames_ok = True
                ok = ok & frames_ok

                if 'preview' in descriptor:
                    reference_npy_fn = os.path.join(test_dir,
                                                    'reference_preview.npy')
                    decoded_npy_fn = os.path.join(work_dir,
                                                  'decoded_preview.npy')

                    if not os.path.exists(decoded_npy_fn):
                        ok = Failure(
                            'File not decoded: decoded_preview.npy')

                    reference_npy = numpy.load(reference_npy_fn)
                    decoded_npy = numpy.load(decoded_npy_fn)
                    preview_ok = CompareNPY(reference_npy, reference_icc,
                                            decoded_npy, decoded_icc, 0,
                                            descriptor['preview']['rms_error'],
                                            descriptor['preview']['peak_error'])
                    if not preview_ok & args.update_on_failure:
                        os.unlink(reference_npy_fn)
                        shutil.copy2(decoded_npy_fn, reference_npy_fn)
                        preview_ok = True
                    ok = ok & preview_ok

    return ok


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--decoder',
                        metavar='DECODER',
                        required=True,
                        help='path to the decoder binary under test.')
    parser.add_argument(
        '--corpus',
        metavar='CORPUS',
        required=True,
        help=('path to the corpus directory or corpus descriptor'
              ' text file.'))
    parser.add_argument(
        '--update_on_failure', action='store_true',
        help='If set, updates reference files on failing checks.')
    args = parser.parse_args()
    if not ConformanceTestRunner(args):
        sys.exit(1)


if __name__ == '__main__':
    main()
