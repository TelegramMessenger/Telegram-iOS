// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// This file contains wrapper-functions that are used to build the libjpeg.so
// shared library that is API- and ABI-compatible with libjpeg-turbo's version
// of libjpeg.so.

#include "lib/jpegli/common.h"
#include "lib/jpegli/decode.h"
#include "lib/jpegli/encode.h"
#include "lib/jpegli/error.h"

struct jpeg_error_mgr *jpeg_std_error(struct jpeg_error_mgr *err) {
  return jpegli_std_error(err);
}

void jpeg_abort(j_common_ptr cinfo) { jpegli_abort(cinfo); }

void jpeg_destroy(j_common_ptr cinfo) { jpegli_destroy(cinfo); }

JQUANT_TBL *jpeg_alloc_quant_table(j_common_ptr cinfo) {
  return jpegli_alloc_quant_table(cinfo);
}

JHUFF_TBL *jpeg_alloc_huff_table(j_common_ptr cinfo) {
  return jpegli_alloc_huff_table(cinfo);
}

void jpeg_CreateDecompress(j_decompress_ptr cinfo, int version,
                           size_t structsize) {
  jpegli_CreateDecompress(cinfo, version, structsize);
}

void jpeg_stdio_src(j_decompress_ptr cinfo, FILE *infile) {
  jpegli_stdio_src(cinfo, infile);
}

void jpeg_mem_src(j_decompress_ptr cinfo, const unsigned char *inbuffer,
                  unsigned long insize) {
  jpegli_mem_src(cinfo, inbuffer, insize);
}

int jpeg_read_header(j_decompress_ptr cinfo, boolean require_image) {
  return jpegli_read_header(cinfo, require_image);
}

boolean jpeg_start_decompress(j_decompress_ptr cinfo) {
  return jpegli_start_decompress(cinfo);
}

JDIMENSION jpeg_read_scanlines(j_decompress_ptr cinfo, JSAMPARRAY scanlines,
                               JDIMENSION max_lines) {
  return jpegli_read_scanlines(cinfo, scanlines, max_lines);
}

JDIMENSION jpeg_skip_scanlines(j_decompress_ptr cinfo, JDIMENSION num_lines) {
  return jpegli_skip_scanlines(cinfo, num_lines);
}

void jpeg_crop_scanline(j_decompress_ptr cinfo, JDIMENSION *xoffset,
                        JDIMENSION *width) {
  jpegli_crop_scanline(cinfo, xoffset, width);
}

boolean jpeg_finish_decompress(j_decompress_ptr cinfo) {
  return jpegli_finish_decompress(cinfo);
}

JDIMENSION jpeg_read_raw_data(j_decompress_ptr cinfo, JSAMPIMAGE data,
                              JDIMENSION max_lines) {
  return jpegli_read_raw_data(cinfo, data, max_lines);
}

jvirt_barray_ptr *jpeg_read_coefficients(j_decompress_ptr cinfo) {
  return jpegli_read_coefficients(cinfo);
}

boolean jpeg_has_multiple_scans(j_decompress_ptr cinfo) {
  return jpegli_has_multiple_scans(cinfo);
}

boolean jpeg_start_output(j_decompress_ptr cinfo, int scan_number) {
  return jpegli_start_output(cinfo, scan_number);
}

boolean jpeg_finish_output(j_decompress_ptr cinfo) {
  return jpegli_finish_output(cinfo);
}

boolean jpeg_input_complete(j_decompress_ptr cinfo) {
  return jpegli_input_complete(cinfo);
}

int jpeg_consume_input(j_decompress_ptr cinfo) {
  return jpegli_consume_input(cinfo);
}

#if JPEG_LIB_VERSION >= 80
void jpeg_core_output_dimensions(j_decompress_ptr cinfo) {
  jpegli_core_output_dimensions(cinfo);
}
#endif
void jpeg_calc_output_dimensions(j_decompress_ptr cinfo) {
  jpegli_calc_output_dimensions(cinfo);
}

void jpeg_save_markers(j_decompress_ptr cinfo, int marker_code,
                       unsigned int length_limit) {
  jpegli_save_markers(cinfo, marker_code, length_limit);
}

void jpeg_set_marker_processor(j_decompress_ptr cinfo, int marker_code,
                               jpeg_marker_parser_method routine) {
  jpegli_set_marker_processor(cinfo, marker_code, routine);
}

boolean jpeg_read_icc_profile(j_decompress_ptr cinfo, JOCTET **icc_data_ptr,
                              unsigned int *icc_data_len) {
  return jpegli_read_icc_profile(cinfo, icc_data_ptr, icc_data_len);
}

void jpeg_abort_decompress(j_decompress_ptr cinfo) {
  return jpegli_abort_decompress(cinfo);
}

void jpeg_destroy_decompress(j_decompress_ptr cinfo) {
  return jpegli_destroy_decompress(cinfo);
}

void jpeg_CreateCompress(j_compress_ptr cinfo, int version, size_t structsize) {
  jpegli_CreateCompress(cinfo, version, structsize);
}

void jpeg_stdio_dest(j_compress_ptr cinfo, FILE *outfile) {
  jpegli_stdio_dest(cinfo, outfile);
}

void jpeg_mem_dest(j_compress_ptr cinfo, unsigned char **outbuffer,
                   unsigned long *outsize) {
  jpegli_mem_dest(cinfo, outbuffer, outsize);
}

void jpeg_set_defaults(j_compress_ptr cinfo) { jpegli_set_defaults(cinfo); }

void jpeg_default_colorspace(j_compress_ptr cinfo) {
  jpegli_default_colorspace(cinfo);
}

void jpeg_set_colorspace(j_compress_ptr cinfo, J_COLOR_SPACE colorspace) {
  jpegli_set_colorspace(cinfo, colorspace);
}

void jpeg_set_quality(j_compress_ptr cinfo, int quality,
                      boolean force_baseline) {
  jpegli_set_quality(cinfo, quality, force_baseline);
}

void jpeg_set_linear_quality(j_compress_ptr cinfo, int scale_factor,
                             boolean force_baseline) {
  jpegli_set_linear_quality(cinfo, scale_factor, force_baseline);
}

#if JPEG_LIB_VERSION >= 70
void jpeg_default_qtables(j_compress_ptr cinfo, boolean force_baseline) {
  jpegli_default_qtables(cinfo, force_baseline);
}
#endif

int jpeg_quality_scaling(int quality) {
  return jpegli_quality_scaling(quality);
}

void jpeg_add_quant_table(j_compress_ptr cinfo, int which_tbl,
                          const unsigned int *basic_table, int scale_factor,
                          boolean force_baseline) {
  jpegli_add_quant_table(cinfo, which_tbl, basic_table, scale_factor,
                         force_baseline);
}

void jpeg_simple_progression(j_compress_ptr cinfo) {
  jpegli_simple_progression(cinfo);
}

void jpeg_suppress_tables(j_compress_ptr cinfo, boolean suppress) {
  jpegli_suppress_tables(cinfo, suppress);
}

#if JPEG_LIB_VERSION >= 70
void jpeg_calc_jpeg_dimensions(j_compress_ptr cinfo) {
  jpegli_calc_jpeg_dimensions(cinfo);
}
#endif

void jpeg_copy_critical_parameters(j_decompress_ptr srcinfo,
                                   j_compress_ptr dstinfo) {
  jpegli_copy_critical_parameters(srcinfo, dstinfo);
}

void jpeg_write_m_header(j_compress_ptr cinfo, int marker,
                         unsigned int datalen) {
  jpegli_write_m_header(cinfo, marker, datalen);
}

void jpeg_write_m_byte(j_compress_ptr cinfo, int val) {
  jpegli_write_m_byte(cinfo, val);
}

void jpeg_write_marker(j_compress_ptr cinfo, int marker, const JOCTET *dataptr,
                       unsigned int datalen) {
  jpegli_write_marker(cinfo, marker, dataptr, datalen);
}

void jpeg_write_icc_profile(j_compress_ptr cinfo, const JOCTET *icc_data_ptr,
                            unsigned int icc_data_len) {
  jpegli_write_icc_profile(cinfo, icc_data_ptr, icc_data_len);
}

void jpeg_start_compress(j_compress_ptr cinfo, boolean write_all_tables) {
  jpegli_start_compress(cinfo, write_all_tables);
}

void jpeg_write_tables(j_compress_ptr cinfo) { jpegli_write_tables(cinfo); }

JDIMENSION jpeg_write_scanlines(j_compress_ptr cinfo, JSAMPARRAY scanlines,
                                JDIMENSION num_lines) {
  return jpegli_write_scanlines(cinfo, scanlines, num_lines);
}

JDIMENSION jpeg_write_raw_data(j_compress_ptr cinfo, JSAMPIMAGE data,
                               JDIMENSION num_lines) {
  return jpegli_write_raw_data(cinfo, data, num_lines);
}

void jpeg_write_coefficients(j_compress_ptr cinfo,
                             jvirt_barray_ptr *coef_arrays) {
  jpegli_write_coefficients(cinfo, coef_arrays);
}

void jpeg_finish_compress(j_compress_ptr cinfo) {
  jpegli_finish_compress(cinfo);
}

void jpeg_abort_compress(j_compress_ptr cinfo) { jpegli_abort_compress(cinfo); }

void jpeg_destroy_compress(j_compress_ptr cinfo) {
  jpegli_destroy_compress(cinfo);
}

boolean jpeg_resync_to_restart(j_decompress_ptr cinfo, int desired) {
  return jpegli_resync_to_restart(cinfo, desired);
}

void jpeg_new_colormap(j_decompress_ptr cinfo) { jpegli_new_colormap(cinfo); }
