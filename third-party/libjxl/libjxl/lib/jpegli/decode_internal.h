// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_DECODE_INTERNAL_H_
#define LIB_JPEGLI_DECODE_INTERNAL_H_

#include <stdint.h>
#include <sys/types.h>

#include <vector>

#include "lib/jpegli/common.h"
#include "lib/jpegli/common_internal.h"
#include "lib/jpegli/huffman.h"

namespace jpegli {

static constexpr int kNeedMoreInput = 100;
static constexpr int kHandleRestart = 101;
static constexpr int kHandleMarkerProcessor = 102;
static constexpr int kProcessNextMarker = 103;
static constexpr size_t kAllHuffLutSize = NUM_HUFF_TBLS * kJpegHuffmanLutSize;

typedef int16_t coeff_t;

// State of the decoder that has to be saved before decoding one MCU in case
// we run out of the bitstream.
struct MCUCodingState {
  coeff_t last_dc_coeff[kMaxComponents];
  int eobrun;
  coeff_t coeffs[D_MAX_BLOCKS_IN_MCU * DCTSIZE2];
};

}  // namespace jpegli

// Use this forward-declared libjpeg struct to hold all our private variables.
// TODO(szabadka) Remove variables that have a corresponding version in cinfo.
struct jpeg_decomp_master {
  //
  // Input handling state.
  //
  std::vector<uint8_t> input_buffer_;
  size_t input_buffer_pos_;
  // Number of bits after codestream_pos_ that were already processed.
  size_t codestream_bits_ahead_;
  bool streaming_mode_;

  // Coefficient buffers
  jvirt_barray_ptr* coef_arrays;
  JBLOCKARRAY coeff_rows[jpegli::kMaxComponents];

  //
  // Marker data processing state.
  //
  bool found_soi_;
  bool found_dri_;
  bool found_sof_;
  bool found_eoi_;
  size_t icc_index_;
  size_t icc_total_;
  std::vector<uint8_t> icc_profile_;
  jpegli::HuffmanTableEntry dc_huff_lut_[jpegli::kAllHuffLutSize];
  jpegli::HuffmanTableEntry ac_huff_lut_[jpegli::kAllHuffLutSize];
  uint8_t markers_to_save_[32];
  jpeg_marker_parser_method app_marker_parsers[16];
  jpeg_marker_parser_method com_marker_parser;
  // Whether this jpeg has multiple scans (progressive or non-interleaved
  // sequential).
  bool is_multiscan_;

  // Fields defined by SOF marker.
  size_t iMCU_cols_;
  int h_factor[jpegli::kMaxComponents];
  int v_factor[jpegli::kMaxComponents];

  // Initialized at strat of frame.
  uint16_t scan_progression_[jpegli::kMaxComponents][DCTSIZE2];

  //
  // Per scan state.
  //
  size_t scan_mcu_row_;
  size_t scan_mcu_col_;
  size_t mcu_rows_per_iMCU_row_;
  jpegli::coeff_t last_dc_coeff_[jpegli::kMaxComponents];
  int eobrun_;
  int restarts_to_go_;
  int next_restart_marker_;

  jpegli::MCUCodingState mcu_;

  //
  // Rendering state.
  //
  int output_passes_done_;
  JpegliDataType output_data_type_ = JPEGLI_TYPE_UINT8;
  bool swap_endianness_ = false;
  size_t xoffset_;
  bool need_context_rows_;

  int min_scaled_dct_size;
  int scaled_dct_size[jpegli::kMaxComponents];

  size_t raw_height_[jpegli::kMaxComponents];
  jpegli::RowBuffer<float> raw_output_[jpegli::kMaxComponents];
  jpegli::RowBuffer<float> render_output_[jpegli::kMaxComponents];

  void (*inverse_transform[jpegli::kMaxComponents])(
      const int16_t* JXL_RESTRICT qblock, const float* JXL_RESTRICT dequant,
      const float* JXL_RESTRICT biases, float* JXL_RESTRICT scratch_space,
      float* JXL_RESTRICT output, size_t output_stride, size_t dctsize);

  void (*color_transform)(float* row[jpegli::kMaxComponents], size_t len);

  float* idct_scratch_;
  float* upsample_scratch_;
  uint8_t* output_scratch_;
  int16_t* smoothing_scratch_;
  float* dequant_;
  // 1 = 1pass, 2 = 2pass, 3 = external
  int quant_mode_;
  int quant_pass_;
  int num_colors_[jpegli::kMaxComponents];
  uint8_t* colormap_lut_;
  uint8_t* pixels_;
  JSAMPARRAY scanlines_;
  std::vector<std::vector<uint8_t>> candidate_lists_;
  bool regenerate_inverse_colormap_;
  float* dither_[jpegli::kMaxComponents];
  float* error_row_[2 * jpegli::kMaxComponents];
  size_t dither_size_;
  size_t dither_mask_;

  // Per channel and per frequency statistics about the number of nonzeros and
  // the sum of coefficient absolute values, used in dequantization bias
  // computation.
  int* nonzeros_;
  int* sumabs_;
  size_t num_processed_blocks_[jpegli::kMaxComponents];
  float* biases_;
#define SAVED_COEFS 10
  // This holds the coef_bits of the scan before the current scan,
  // i.e. the bottom half when rendering incomplete scans.
  int (*coef_bits_latch)[SAVED_COEFS];
  int (*prev_coef_bits_latch)[SAVED_COEFS];
  bool apply_smoothing;
};

#endif  // LIB_JPEGLI_DECODE_INTERNAL_H_
