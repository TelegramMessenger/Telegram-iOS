// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// This file conatins the C API of the decoder part of the libjpegli library,
// which is based on the C API of libjpeg, with the function names changed from
// jpeg_* to jpegli_*, while dempressor object definitions are included directly
// from jpeglib.h
//
// Applications can use the libjpegli library in one of the following ways:
//
//  (1) Include jpegli/encode.h and/or jpegli/decode.h, update the function
//      names of the API and link against libjpegli.
//
//  (2) Leave the application code unchanged, but replace the libjpeg.so library
//      with the one built by this project that is API- and ABI-compatible with
//      libjpeg-turbo's version of libjpeg.so.

#ifndef LIB_JPEGLI_DECODE_H_
#define LIB_JPEGLI_DECODE_H_

#include "lib/jpegli/common.h"

#if defined(__cplusplus) || defined(c_plusplus)
extern "C" {
#endif

#define jpegli_create_decompress(cinfo)              \
  jpegli_CreateDecompress((cinfo), JPEG_LIB_VERSION, \
                          (size_t)sizeof(struct jpeg_decompress_struct))

void jpegli_CreateDecompress(j_decompress_ptr cinfo, int version,
                             size_t structsize);

void jpegli_stdio_src(j_decompress_ptr cinfo, FILE *infile);

void jpegli_mem_src(j_decompress_ptr cinfo, const unsigned char *inbuffer,
                    unsigned long insize);

int jpegli_read_header(j_decompress_ptr cinfo, boolean require_image);

boolean jpegli_start_decompress(j_decompress_ptr cinfo);

JDIMENSION jpegli_read_scanlines(j_decompress_ptr cinfo, JSAMPARRAY scanlines,
                                 JDIMENSION max_lines);

JDIMENSION jpegli_skip_scanlines(j_decompress_ptr cinfo, JDIMENSION num_lines);

void jpegli_crop_scanline(j_decompress_ptr cinfo, JDIMENSION *xoffset,
                          JDIMENSION *width);

boolean jpegli_finish_decompress(j_decompress_ptr cinfo);

JDIMENSION jpegli_read_raw_data(j_decompress_ptr cinfo, JSAMPIMAGE data,
                                JDIMENSION max_lines);

jvirt_barray_ptr *jpegli_read_coefficients(j_decompress_ptr cinfo);

boolean jpegli_has_multiple_scans(j_decompress_ptr cinfo);

boolean jpegli_start_output(j_decompress_ptr cinfo, int scan_number);

boolean jpegli_finish_output(j_decompress_ptr cinfo);

boolean jpegli_input_complete(j_decompress_ptr cinfo);

int jpegli_consume_input(j_decompress_ptr cinfo);

#if JPEG_LIB_VERSION >= 80
void jpegli_core_output_dimensions(j_decompress_ptr cinfo);
#endif
void jpegli_calc_output_dimensions(j_decompress_ptr cinfo);

void jpegli_save_markers(j_decompress_ptr cinfo, int marker_code,
                         unsigned int length_limit);

void jpegli_set_marker_processor(j_decompress_ptr cinfo, int marker_code,
                                 jpeg_marker_parser_method routine);

boolean jpegli_resync_to_restart(j_decompress_ptr cinfo, int desired);

boolean jpegli_read_icc_profile(j_decompress_ptr cinfo, JOCTET **icc_data_ptr,
                                unsigned int *icc_data_len);

void jpegli_abort_decompress(j_decompress_ptr cinfo);

void jpegli_destroy_decompress(j_decompress_ptr cinfo);

void jpegli_new_colormap(j_decompress_ptr cinfo);

//
// New API functions that are not available in libjpeg
//
// NOTE: This part of the API is still experimental and will probably change in
// the future.
//

void jpegli_set_output_format(j_decompress_ptr cinfo, JpegliDataType data_type,
                              JpegliEndianness endianness);

#if defined(__cplusplus) || defined(c_plusplus)
}  // extern "C"
#endif

#endif  // LIB_JPEGLI_DECODE_H_
