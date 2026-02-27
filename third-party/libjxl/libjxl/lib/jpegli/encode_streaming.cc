// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/encode_streaming.h"

#include <cmath>

#include "lib/jpegli/bit_writer.h"
#include "lib/jpegli/bitstream.h"
#include "lib/jpegli/entropy_coding.h"
#include "lib/jpegli/error.h"
#include "lib/jpegli/memory_manager.h"
#include "lib/jxl/base/bits.h"

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jpegli/encode_streaming.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jpegli/dct-inl.h"
#include "lib/jpegli/entropy_coding-inl.h"

HWY_BEFORE_NAMESPACE();
namespace jpegli {
namespace HWY_NAMESPACE {

static const int kStreamingModeCoefficients = 0;
static const int kStreamingModeTokens = 1;
static const int kStreamingModeBits = 2;

namespace {
void ZigZagShuffle(int32_t* JXL_RESTRICT block) {
  // TODO(szabadka) SIMDify this.
  int32_t tmp[DCTSIZE2];
  tmp[0] = block[0];
  tmp[1] = block[1];
  tmp[2] = block[8];
  tmp[3] = block[16];
  tmp[4] = block[9];
  tmp[5] = block[2];
  tmp[6] = block[3];
  tmp[7] = block[10];
  tmp[8] = block[17];
  tmp[9] = block[24];
  tmp[10] = block[32];
  tmp[11] = block[25];
  tmp[12] = block[18];
  tmp[13] = block[11];
  tmp[14] = block[4];
  tmp[15] = block[5];
  tmp[16] = block[12];
  tmp[17] = block[19];
  tmp[18] = block[26];
  tmp[19] = block[33];
  tmp[20] = block[40];
  tmp[21] = block[48];
  tmp[22] = block[41];
  tmp[23] = block[34];
  tmp[24] = block[27];
  tmp[25] = block[20];
  tmp[26] = block[13];
  tmp[27] = block[6];
  tmp[28] = block[7];
  tmp[29] = block[14];
  tmp[30] = block[21];
  tmp[31] = block[28];
  tmp[32] = block[35];
  tmp[33] = block[42];
  tmp[34] = block[49];
  tmp[35] = block[56];
  tmp[36] = block[57];
  tmp[37] = block[50];
  tmp[38] = block[43];
  tmp[39] = block[36];
  tmp[40] = block[29];
  tmp[41] = block[22];
  tmp[42] = block[15];
  tmp[43] = block[23];
  tmp[44] = block[30];
  tmp[45] = block[37];
  tmp[46] = block[44];
  tmp[47] = block[51];
  tmp[48] = block[58];
  tmp[49] = block[59];
  tmp[50] = block[52];
  tmp[51] = block[45];
  tmp[52] = block[38];
  tmp[53] = block[31];
  tmp[54] = block[39];
  tmp[55] = block[46];
  tmp[56] = block[53];
  tmp[57] = block[60];
  tmp[58] = block[61];
  tmp[59] = block[54];
  tmp[60] = block[47];
  tmp[61] = block[55];
  tmp[62] = block[62];
  tmp[63] = block[63];
  memcpy(block, tmp, DCTSIZE2 * sizeof(tmp[0]));
}
}  // namespace

template <int kMode>
void ProcessiMCURow(j_compress_ptr cinfo) {
  jpeg_comp_master* m = cinfo->master;
  JpegBitWriter* bw = &m->bw;
  int xsize_mcus = DivCeil(cinfo->image_width, 8 * cinfo->max_h_samp_factor);
  int ysize_mcus = DivCeil(cinfo->image_height, 8 * cinfo->max_v_samp_factor);
  int mcu_y = m->next_iMCU_row;
  int32_t* block = m->block_tmp;
  int32_t* symbols = m->block_tmp + DCTSIZE2;
  int32_t* nonzero_idx = m->block_tmp + 3 * DCTSIZE2;
  coeff_t* JXL_RESTRICT last_dc_coeff = m->last_dc_coeff;
  bool adaptive_quant = m->use_adaptive_quantization && m->psnr_target == 0;
  JBLOCKARRAY ba[kMaxComponents];
  if (kMode == kStreamingModeCoefficients) {
    for (int c = 0; c < cinfo->num_components; ++c) {
      jpeg_component_info* comp = &cinfo->comp_info[c];
      int by0 = mcu_y * comp->v_samp_factor;
      int block_rows_left = comp->height_in_blocks - by0;
      int max_block_rows = std::min(comp->v_samp_factor, block_rows_left);
      ba[c] = (*cinfo->mem->access_virt_barray)(
          reinterpret_cast<j_common_ptr>(cinfo), m->coeff_buffers[c], by0,
          max_block_rows, true);
    }
  }
  if (kMode == kStreamingModeTokens) {
    TokenArray* ta = &m->token_arrays[m->cur_token_array];
    int max_tokens_per_mcu_row = MaxNumTokensPerMCURow(cinfo);
    if (ta->num_tokens + max_tokens_per_mcu_row > m->num_tokens) {
      if (ta->tokens) {
        m->total_num_tokens += ta->num_tokens;
        ++m->cur_token_array;
        ta = &m->token_arrays[m->cur_token_array];
      }
      m->num_tokens =
          EstimateNumTokens(cinfo, mcu_y, ysize_mcus, m->total_num_tokens,
                            max_tokens_per_mcu_row);
      ta->tokens = Allocate<Token>(cinfo, m->num_tokens, JPOOL_IMAGE);
      m->next_token = ta->tokens;
    }
  }
  const float* imcu_start[kMaxComponents];
  for (int c = 0; c < cinfo->num_components; ++c) {
    jpeg_component_info* comp = &cinfo->comp_info[c];
    imcu_start[c] = m->raw_data[c]->Row(mcu_y * comp->v_samp_factor * DCTSIZE);
  }
  const float* qf = nullptr;
  if (adaptive_quant) {
    qf = m->quant_field.Row(0);
  }
  HuffmanCodeTable* dc_code = nullptr;
  HuffmanCodeTable* ac_code = nullptr;
  const size_t qf_stride = m->quant_field.stride();
  for (int mcu_x = 0; mcu_x < xsize_mcus; ++mcu_x) {
    for (int c = 0; c < cinfo->num_components; ++c) {
      jpeg_component_info* comp = &cinfo->comp_info[c];
      if (kMode == kStreamingModeBits) {
        dc_code = &m->coding_tables[m->context_map[c]];
        ac_code = &m->coding_tables[m->context_map[c + 4]];
      }
      float* JXL_RESTRICT qmc = m->quant_mul[c];
      const size_t stride = m->raw_data[c]->stride();
      const int h_factor = m->h_factor[c];
      const float* zero_bias_offset = m->zero_bias_offset[c];
      const float* zero_bias_mul = m->zero_bias_mul[c];
      float aq_strength = 0.0f;
      for (int iy = 0; iy < comp->v_samp_factor; ++iy) {
        for (int ix = 0; ix < comp->h_samp_factor; ++ix) {
          size_t by = mcu_y * comp->v_samp_factor + iy;
          size_t bx = mcu_x * comp->h_samp_factor + ix;
          if (bx >= comp->width_in_blocks || by >= comp->height_in_blocks) {
            if (kMode == kStreamingModeTokens) {
              *m->next_token++ = Token(c, 0, 0);
              *m->next_token++ = Token(c + 4, 0, 0);
            } else if (kMode == kStreamingModeBits) {
              WriteBits(bw, dc_code->depth[0], dc_code->code[0]);
              WriteBits(bw, ac_code->depth[0], ac_code->code[0]);
            }
            continue;
          }
          if (adaptive_quant) {
            aq_strength = qf[iy * qf_stride + bx * h_factor];
          }
          const float* pixels = imcu_start[c] + (iy * stride + bx) * DCTSIZE;
          ComputeCoefficientBlock(pixels, stride, qmc, last_dc_coeff[c],
                                  aq_strength, zero_bias_offset, zero_bias_mul,
                                  m->dct_buffer, block);
          if (kMode == kStreamingModeCoefficients) {
            JCOEF* cblock = &ba[c][iy][bx][0];
            for (int k = 0; k < DCTSIZE2; ++k) {
              cblock[k] = block[kJPEGNaturalOrder[k]];
            }
          }
          block[0] -= last_dc_coeff[c];
          last_dc_coeff[c] += block[0];
          if (kMode == kStreamingModeTokens) {
            ComputeTokensForBlock<int32_t, false>(block, 0, c, c + 4,
                                                  &m->next_token);
          } else if (kMode == kStreamingModeBits) {
            ZigZagShuffle(block);
            const int num_nonzeros = CompactBlock(block, nonzero_idx);
            const bool emit_eob = nonzero_idx[num_nonzeros - 1] < 1008;
            ComputeSymbols(num_nonzeros, nonzero_idx, block, symbols);
            WriteBlock(symbols, block, num_nonzeros, emit_eob, dc_code, ac_code,
                       bw);
          }
        }
      }
    }
  }
  if (kMode == kStreamingModeTokens) {
    TokenArray* ta = &m->token_arrays[m->cur_token_array];
    ta->num_tokens = m->next_token - ta->tokens;
    ScanTokenInfo* sti = &m->scan_token_info[0];
    sti->num_tokens = m->total_num_tokens + ta->num_tokens;
    sti->restarts[0] = sti->num_tokens;
  }
}

void ComputeCoefficientsForiMCURow(j_compress_ptr cinfo) {
  ProcessiMCURow<kStreamingModeCoefficients>(cinfo);
}

void ComputeTokensForiMCURow(j_compress_ptr cinfo) {
  ProcessiMCURow<kStreamingModeTokens>(cinfo);
}

void WriteiMCURow(j_compress_ptr cinfo) {
  ProcessiMCURow<kStreamingModeBits>(cinfo);
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jpegli
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jpegli {
HWY_EXPORT(ComputeCoefficientsForiMCURow);
HWY_EXPORT(ComputeTokensForiMCURow);
HWY_EXPORT(WriteiMCURow);

void ComputeCoefficientsForiMCURow(j_compress_ptr cinfo) {
  HWY_DYNAMIC_DISPATCH(ComputeCoefficientsForiMCURow)(cinfo);
}

void ComputeTokensForiMCURow(j_compress_ptr cinfo) {
  HWY_DYNAMIC_DISPATCH(ComputeTokensForiMCURow)(cinfo);
}

void WriteiMCURow(j_compress_ptr cinfo) {
  HWY_DYNAMIC_DISPATCH(WriteiMCURow)(cinfo);
}

}  // namespace jpegli
#endif  // HWY_ONCE
