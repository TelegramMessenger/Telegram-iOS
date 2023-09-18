// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_ENCODE_INTERNAL_H_
#define LIB_JPEGLI_ENCODE_INTERNAL_H_

#include <stdint.h>

#include "lib/jpegli/bit_writer.h"
#include "lib/jpegli/common.h"
#include "lib/jpegli/common_internal.h"
#include "lib/jpegli/encode.h"

namespace jpegli {

constexpr unsigned char kICCSignature[12] = {
    0x49, 0x43, 0x43, 0x5F, 0x50, 0x52, 0x4F, 0x46, 0x49, 0x4C, 0x45, 0x00};
constexpr int kICCMarker = JPEG_APP0 + 2;

constexpr int kDefaultProgressiveLevel = 0;

typedef int16_t coeff_t;

struct HuffmanCodeTable {
  int depth[256];
  int code[256];
};

struct Token {
  uint8_t context;
  uint8_t symbol;
  uint16_t bits;
  Token(int c, int s, int b) : context(c), symbol(s), bits(b) {}
};

struct TokenArray {
  Token* tokens;
  size_t num_tokens;
};

struct RefToken {
  uint8_t symbol;
  uint8_t refbits;
};

struct ScanTokenInfo {
  RefToken* tokens;
  size_t num_tokens;
  uint8_t* refbits;
  uint16_t* eobruns;
  size_t* restarts;
  size_t num_restarts;
  size_t num_nonzeros;
  size_t num_future_nonzeros;
  size_t token_offset;
  size_t restart_interval;
  size_t MCUs_per_row;
  size_t MCU_rows_in_scan;
  size_t blocks_in_MCU;
  size_t num_blocks;
};

}  // namespace jpegli

struct jpeg_comp_master {
  jpegli::RowBuffer<float> input_buffer[jpegli::kMaxComponents];
  jpegli::RowBuffer<float>* smooth_input[jpegli::kMaxComponents];
  jpegli::RowBuffer<float>* raw_data[jpegli::kMaxComponents];
  bool force_baseline;
  bool xyb_mode;
  uint8_t cicp_transfer_function;
  bool use_std_tables;
  bool use_adaptive_quantization;
  int progressive_level;
  size_t xsize_blocks;
  size_t ysize_blocks;
  size_t blocks_per_iMCU_row;
  jpegli::ScanTokenInfo* scan_token_info;
  JpegliDataType data_type;
  JpegliEndianness endianness;
  void (*input_method)(const uint8_t* row_in, size_t len,
                       float* row_out[jpegli::kMaxComponents]);
  void (*color_transform)(float* row[jpegli::kMaxComponents], size_t len);
  void (*downsample_method[jpegli::kMaxComponents])(
      float* rows_in[MAX_SAMP_FACTOR], size_t len, float* row_out);
  float* quant_mul[jpegli::kMaxComponents];
  float* zero_bias_offset[jpegli::kMaxComponents];
  float* zero_bias_mul[jpegli::kMaxComponents];
  int h_factor[jpegli::kMaxComponents];
  int v_factor[jpegli::kMaxComponents];
  // Array of Huffman tables that will be encoded in one or more DHT segments.
  // In progressive mode we compute all Huffman tables that will be used in any
  // of the scans, thus we can have more than 4 tables here.
  JHUFF_TBL* huffman_tables;
  size_t num_huffman_tables;
  // Array of num_huffman_tables slot ids, where the ith element is the slot id
  // of the ith Huffman table, as it appears in the DHT segment. The range of
  // the slot ids is 0..3 for DC and 16..19 for AC Huffman codes.
  uint8_t* slot_id_map;
  // Maps context ids to an index in the huffman_tables array. Each component in
  // each scan has a DC and AC context id, which are defined as follows:
  //   - DC context id is the component index (relative to cinfo->comp_info) of
  //     the scan component
  //   - AC context ids start at 4 and are increased for each component of each
  //     scan that have AC components (i.e. Se > 0)
  uint8_t* context_map;
  size_t num_contexts;
  // Array of cinfo->num_scans context ids, where the ith element is the context
  // id of the first AC component of the ith scan.
  uint8_t* ac_ctx_offset;
  // Array of num_huffman tables derived coding tables.
  jpegli::HuffmanCodeTable* coding_tables;
  float* diff_buffer;
  jpegli::RowBuffer<float> fuzzy_erosion_tmp;
  jpegli::RowBuffer<float> pre_erosion;
  jpegli::RowBuffer<float> quant_field;
  jvirt_barray_ptr* coeff_buffers;
  size_t next_input_row;
  size_t next_iMCU_row;
  size_t next_dht_index;
  size_t last_restart_interval;
  JCOEF last_dc_coeff[MAX_COMPS_IN_SCAN];
  jpegli::JpegBitWriter bw;
  float* dct_buffer;
  int32_t* block_tmp;
  jpegli::TokenArray* token_arrays;
  size_t cur_token_array;
  jpegli::Token* next_token;
  size_t num_tokens;
  size_t total_num_tokens;
  jpegli::RefToken* next_refinement_token;
  uint8_t* next_refinement_bit;
  float psnr_target;
  float psnr_tolerance;
  float min_distance;
  float max_distance;
};

#endif  // LIB_JPEGLI_ENCODE_INTERNAL_H_
