// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// This file conatins the C API of the common encoder/decoder part of libjpegli
// library, which is based on the C API of libjpeg, with the function names
// changed from jpeg_* to jpegli_*, while compressor and dempressor object
// definitions are included directly from jpeglib.h
//
// Applications can use the libjpegli library in one of the following ways:
//
//  (1) Include jpegli/encode.h and/or jpegli/decode.h, update the function
//      names of the API and link against libjpegli.
//
//  (2) Leave the application code unchanged, but replace the libjpeg.so library
//      with the one built by this project that is API- and ABI-compatible with
//      libjpeg-turbo's version of libjpeg.so.

#ifndef LIB_JPEGLI_COMMON_H_
#define LIB_JPEGLI_COMMON_H_

/* clang-format off */
#include <stdio.h>
#include <jpeglib.h>
/* clang-format on */

#include "lib/jpegli/types.h"

#if defined(__cplusplus) || defined(c_plusplus)
extern "C" {
#endif

struct jpeg_error_mgr* jpegli_std_error(struct jpeg_error_mgr* err);

void jpegli_abort(j_common_ptr cinfo);

void jpegli_destroy(j_common_ptr cinfo);

JQUANT_TBL* jpegli_alloc_quant_table(j_common_ptr cinfo);

JHUFF_TBL* jpegli_alloc_huff_table(j_common_ptr cinfo);

#if defined(__cplusplus) || defined(c_plusplus)
}  // extern "C"
#endif

#endif  // LIB_JPEGLI_COMMON_H_
