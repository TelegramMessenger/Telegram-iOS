#!/usr/bin/env python3
# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

import ctypes
from numpy.ctypeslib import ndpointer
import numpy
import os

lcms2_lib_path = os.getenv("LCMS2_LIB_PATH", "liblcms2.so.2")
lcms2_lib = ctypes.cdll.LoadLibrary(lcms2_lib_path)

native_open_profile = lcms2_lib.cmsOpenProfileFromMem
native_open_profile.restype = ctypes.c_void_p
native_open_profile.argtypes = [
    ctypes.c_char_p,  # MemPtr
    ctypes.c_size_t  # dwSize
]

native_close_profile = lcms2_lib.cmsCloseProfile
native_close_profile.restype = ctypes.c_int
native_close_profile.argtypes = [
    ctypes.c_void_p  # hProfile
]

native_create_transform = lcms2_lib.cmsCreateTransform
native_create_transform.restype = ctypes.c_void_p
native_create_transform.argtypes = [
    ctypes.c_void_p,  # Input
    ctypes.c_uint32,  # InputFormat
    ctypes.c_void_p,  # Output
    ctypes.c_uint32,  # OutputFormat
    ctypes.c_uint32,  # Intent
    ctypes.c_uint32  # dwFlags
]

native_delete_transform = lcms2_lib.cmsDeleteTransform
native_delete_transform.restype = None
native_delete_transform.argtypes = [
    ctypes.c_void_p  # hTransform
]

native_do_transform = lcms2_lib.cmsDoTransform
native_do_transform.restype = None
native_do_transform.argtypes = [
    ctypes.c_void_p,  # Transform
    ndpointer(ctypes.c_double, flags="C_CONTIGUOUS"),  # InputBuffer
    ndpointer(ctypes.c_double, flags="C_CONTIGUOUS"),  # OutputBuffer
    ctypes.c_uint32  # Size
]


def make_format(
    bytes_per_sample=4,  # float32
    num_channels=3,  # RGB or XYZ
    extra_channels=0,
    swap_channels=0,
    swap_endiannes=0,
    planar=0,
    flavor=0,
    swap_first=0,
    unused=0,
    pixel_type=4,  # RGB
    optimized=0,
    floating_point=1):
    values = [bytes_per_sample, num_channels, extra_channels, swap_channels,
        swap_endiannes, planar, flavor, swap_first, unused, pixel_type,
        optimized, floating_point]
    bit_width = [3, 4, 3, 1, 1, 1, 1, 1, 1, 5, 1, 1]
    result = 0
    shift = 0
    for i in range(len(bit_width)):
        result += values[i] << shift
        shift += bit_width[i]
    return result


def convert_pixels(from_icc, to_icc, from_pixels):
    from_icc = bytearray(from_icc)
    to_icc = bytearray(to_icc)

    if len(from_pixels.shape) != 3 or from_pixels.shape[2] != 3:
        raise ValueError("Only WxHx3 shapes are supported")
    from_pixels_plain = from_pixels.ravel().astype(numpy.float64)
    num_pixels = len(from_pixels_plain) // 3
    to_pixels_plain = numpy.empty(num_pixels * 3, dtype=numpy.float64)

    from_icc = (ctypes.c_char * len(from_icc)).from_buffer(from_icc)
    from_profile = native_open_profile(
        ctypes.cast(ctypes.pointer(from_icc), ctypes.c_char_p), len(from_icc))

    to_icc = (ctypes.c_char * len(to_icc)).from_buffer(to_icc)
    to_profile = native_open_profile(
        ctypes.cast(ctypes.pointer(to_icc), ctypes.c_char_p), len(to_icc))

    # bytes_per_sample=0 actually means 8 bytes (but there are just 3 bits to
    # encode the length of sample)
    format_rgb_f64 = make_format(bytes_per_sample=0)
    intent = 0  # INTENT_PERCEPTUAL
    flags = 0  # default; no "no-optimization"
    transform = native_create_transform(
        from_profile, format_rgb_f64, to_profile, format_rgb_f64, intent, flags)

    native_do_transform(
        transform, from_pixels_plain, to_pixels_plain, num_pixels)

    native_delete_transform(transform)
    native_close_profile(to_profile)
    native_close_profile(from_profile)

    # Return same shape and size as input
    return to_pixels_plain.reshape(from_pixels.shape).astype(from_pixels.dtype)

if __name__ == '__main__':
    raise Exception("Not an executable")
