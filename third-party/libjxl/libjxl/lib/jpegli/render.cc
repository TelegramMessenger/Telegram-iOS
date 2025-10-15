// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/render.h"

#include <string.h>

#include <array>
#include <atomic>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <hwy/aligned_allocator.h>
#include <vector>

#include "lib/jpegli/color_quantize.h"
#include "lib/jpegli/color_transform.h"
#include "lib/jpegli/decode_internal.h"
#include "lib/jpegli/error.h"
#include "lib/jpegli/idct.h"
#include "lib/jpegli/upsample.h"
#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/status.h"

#ifdef MEMORY_SANITIZER
#define JXL_MEMORY_SANITIZER 1
#elif defined(__has_feature)
#if __has_feature(memory_sanitizer)
#define JXL_MEMORY_SANITIZER 1
#else
#define JXL_MEMORY_SANITIZER 0
#endif
#else
#define JXL_MEMORY_SANITIZER 0
#endif

#if JXL_MEMORY_SANITIZER
#include "sanitizer/msan_interface.h"
#endif

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jpegli/render.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

HWY_BEFORE_NAMESPACE();
namespace jpegli {
namespace HWY_NAMESPACE {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::Abs;
using hwy::HWY_NAMESPACE::Add;
using hwy::HWY_NAMESPACE::Clamp;
using hwy::HWY_NAMESPACE::Gt;
using hwy::HWY_NAMESPACE::IfThenElseZero;
using hwy::HWY_NAMESPACE::Mul;
using hwy::HWY_NAMESPACE::NearestInt;
using hwy::HWY_NAMESPACE::Or;
using hwy::HWY_NAMESPACE::Rebind;
using hwy::HWY_NAMESPACE::ShiftLeftSame;
using hwy::HWY_NAMESPACE::ShiftRightSame;
using hwy::HWY_NAMESPACE::Vec;
using D = HWY_FULL(float);
using DI = HWY_FULL(int32_t);
constexpr D d;
constexpr DI di;

void GatherBlockStats(const int16_t* JXL_RESTRICT coeffs,
                      const size_t coeffs_size, int32_t* JXL_RESTRICT nonzeros,
                      int32_t* JXL_RESTRICT sumabs) {
  for (size_t i = 0; i < coeffs_size; i += Lanes(d)) {
    size_t k = i % DCTSIZE2;
    const Rebind<int16_t, DI> di16;
    const Vec<DI> coeff = PromoteTo(di, Load(di16, coeffs + i));
    const auto abs_coeff = Abs(coeff);
    const auto not_0 = Gt(abs_coeff, Zero(di));
    const auto nzero = IfThenElseZero(not_0, Set(di, 1));
    Store(Add(nzero, Load(di, nonzeros + k)), di, nonzeros + k);
    Store(Add(abs_coeff, Load(di, sumabs + k)), di, sumabs + k);
  }
}

void DecenterRow(float* row, size_t xsize) {
  const HWY_CAPPED(float, 8) df;
  const auto c128 = Set(df, 128.0f / 255);
  for (size_t x = 0; x < xsize; x += Lanes(df)) {
    Store(Add(Load(df, row + x), c128), df, row + x);
  }
}

void DitherRow(j_decompress_ptr cinfo, float* row, int c, size_t y,
               size_t xsize) {
  jpeg_decomp_master* m = cinfo->master;
  if (!m->dither_[c]) return;
  const float* dither_row =
      &m->dither_[c][(y & m->dither_mask_) * m->dither_size_];
  for (size_t x = 0; x < xsize; ++x) {
    row[x] += dither_row[x & m->dither_mask_];
  }
}

template <typename T>
void StoreUnsignedRow(float* JXL_RESTRICT input[], size_t x0, size_t len,
                      size_t num_channels, float multiplier, T* output) {
  const HWY_CAPPED(float, 8) d;
  auto zero = Zero(d);
  auto mul = Set(d, multiplier);
  const Rebind<T, decltype(d)> du;
#if JXL_MEMORY_SANITIZER
  const size_t padding = hwy::RoundUpTo(len, Lanes(d)) - len;
  for (size_t c = 0; c < num_channels; ++c) {
    __msan_unpoison(input[c] + x0 + len, sizeof(input[c][0]) * padding);
  }
#endif
  if (num_channels == 1) {
    for (size_t i = 0; i < len; i += Lanes(d)) {
      auto v0 = Clamp(zero, Mul(LoadU(d, &input[0][x0 + i]), mul), mul);
      StoreU(DemoteTo(du, NearestInt(v0)), du, &output[i]);
    }
  } else if (num_channels == 2) {
    for (size_t i = 0; i < len; i += Lanes(d)) {
      auto v0 = Clamp(zero, Mul(LoadU(d, &input[0][x0 + i]), mul), mul);
      auto v1 = Clamp(zero, Mul(LoadU(d, &input[1][x0 + i]), mul), mul);
      StoreInterleaved2(DemoteTo(du, NearestInt(v0)),
                        DemoteTo(du, NearestInt(v1)), du, &output[2 * i]);
    }
  } else if (num_channels == 3) {
    for (size_t i = 0; i < len; i += Lanes(d)) {
      auto v0 = Clamp(zero, Mul(LoadU(d, &input[0][x0 + i]), mul), mul);
      auto v1 = Clamp(zero, Mul(LoadU(d, &input[1][x0 + i]), mul), mul);
      auto v2 = Clamp(zero, Mul(LoadU(d, &input[2][x0 + i]), mul), mul);
      StoreInterleaved3(DemoteTo(du, NearestInt(v0)),
                        DemoteTo(du, NearestInt(v1)),
                        DemoteTo(du, NearestInt(v2)), du, &output[3 * i]);
    }
  } else if (num_channels == 4) {
    for (size_t i = 0; i < len; i += Lanes(d)) {
      auto v0 = Clamp(zero, Mul(LoadU(d, &input[0][x0 + i]), mul), mul);
      auto v1 = Clamp(zero, Mul(LoadU(d, &input[1][x0 + i]), mul), mul);
      auto v2 = Clamp(zero, Mul(LoadU(d, &input[2][x0 + i]), mul), mul);
      auto v3 = Clamp(zero, Mul(LoadU(d, &input[3][x0 + i]), mul), mul);
      StoreInterleaved4(DemoteTo(du, NearestInt(v0)),
                        DemoteTo(du, NearestInt(v1)),
                        DemoteTo(du, NearestInt(v2)),
                        DemoteTo(du, NearestInt(v3)), du, &output[4 * i]);
    }
  }
#if JXL_MEMORY_SANITIZER
  __msan_poison(output + num_channels * len,
                sizeof(output[0]) * num_channels * padding);
#endif
}

void StoreFloatRow(float* JXL_RESTRICT input[3], size_t x0, size_t len,
                   size_t num_channels, float* output) {
  const HWY_CAPPED(float, 8) d;
  if (num_channels == 1) {
    memcpy(output, input[0] + x0, len * sizeof(output[0]));
  } else if (num_channels == 2) {
    for (size_t i = 0; i < len; i += Lanes(d)) {
      StoreInterleaved2(LoadU(d, &input[0][x0 + i]),
                        LoadU(d, &input[1][x0 + i]), d, &output[2 * i]);
    }
  } else if (num_channels == 3) {
    for (size_t i = 0; i < len; i += Lanes(d)) {
      StoreInterleaved3(LoadU(d, &input[0][x0 + i]),
                        LoadU(d, &input[1][x0 + i]),
                        LoadU(d, &input[2][x0 + i]), d, &output[3 * i]);
    }
  } else if (num_channels == 4) {
    for (size_t i = 0; i < len; i += Lanes(d)) {
      StoreInterleaved4(LoadU(d, &input[0][x0 + i]),
                        LoadU(d, &input[1][x0 + i]),
                        LoadU(d, &input[2][x0 + i]),
                        LoadU(d, &input[3][x0 + i]), d, &output[4 * i]);
    }
  }
}

static constexpr float kFSWeightMR = 7.0f / 16.0f;
static constexpr float kFSWeightBL = 3.0f / 16.0f;
static constexpr float kFSWeightBM = 5.0f / 16.0f;
static constexpr float kFSWeightBR = 1.0f / 16.0f;

float LimitError(float error) {
  float abserror = std::abs(error);
  if (abserror > 48.0f) {
    abserror = 32.0f;
  } else if (abserror > 16.0f) {
    abserror = 0.5f * abserror + 8.0f;
  }
  return error > 0.0f ? abserror : -abserror;
}

void WriteToOutput(j_decompress_ptr cinfo, float* JXL_RESTRICT rows[],
                   size_t xoffset, size_t len, size_t num_channels,
                   uint8_t* JXL_RESTRICT output) {
  jpeg_decomp_master* m = cinfo->master;
  uint8_t* JXL_RESTRICT scratch_space = m->output_scratch_;
  if (cinfo->quantize_colors && m->quant_pass_ == 1) {
    float* error_row[kMaxComponents];
    float* next_error_row[kMaxComponents];
    if (cinfo->dither_mode == JDITHER_ORDERED) {
      for (size_t c = 0; c < num_channels; ++c) {
        DitherRow(cinfo, &rows[c][xoffset], c, cinfo->output_scanline,
                  cinfo->output_width);
      }
    } else if (cinfo->dither_mode == JDITHER_FS) {
      for (size_t c = 0; c < num_channels; ++c) {
        if (cinfo->output_scanline % 2 == 0) {
          error_row[c] = m->error_row_[c];
          next_error_row[c] = m->error_row_[c + kMaxComponents];
        } else {
          error_row[c] = m->error_row_[c + kMaxComponents];
          next_error_row[c] = m->error_row_[c];
        }
        memset(next_error_row[c], 0.0, cinfo->output_width * sizeof(float));
      }
    }
    const float mul = 255.0f;
    if (cinfo->dither_mode != JDITHER_FS) {
      StoreUnsignedRow(rows, xoffset, len, num_channels, mul, scratch_space);
    }
    for (size_t i = 0; i < len; ++i) {
      uint8_t* pixel = &scratch_space[num_channels * i];
      if (cinfo->dither_mode == JDITHER_FS) {
        for (size_t c = 0; c < num_channels; ++c) {
          float val = rows[c][i] * mul + LimitError(error_row[c][i]);
          pixel[c] = std::round(std::min(255.0f, std::max(0.0f, val)));
        }
      }
      int index = LookupColorIndex(cinfo, pixel);
      output[i] = index;
      if (cinfo->dither_mode == JDITHER_FS) {
        size_t prev_i = i > 0 ? i - 1 : 0;
        size_t next_i = i + 1 < len ? i + 1 : len - 1;
        for (size_t c = 0; c < num_channels; ++c) {
          float error = pixel[c] - cinfo->colormap[c][index];
          error_row[c][next_i] += kFSWeightMR * error;
          next_error_row[c][prev_i] += kFSWeightBL * error;
          next_error_row[c][i] += kFSWeightBM * error;
          next_error_row[c][next_i] += kFSWeightBR * error;
        }
      }
    }
  } else if (m->output_data_type_ == JPEGLI_TYPE_UINT8) {
    const float mul = 255.0;
    StoreUnsignedRow(rows, xoffset, len, num_channels, mul, scratch_space);
    memcpy(output, scratch_space, len * num_channels);
  } else if (m->output_data_type_ == JPEGLI_TYPE_UINT16) {
    const float mul = 65535.0;
    uint16_t* tmp = reinterpret_cast<uint16_t*>(scratch_space);
    StoreUnsignedRow(rows, xoffset, len, num_channels, mul, tmp);
    if (m->swap_endianness_) {
      const HWY_CAPPED(uint16_t, 8) du;
      size_t output_len = len * num_channels;
      for (size_t j = 0; j < output_len; j += Lanes(du)) {
        auto v = LoadU(du, tmp + j);
        auto vswap = Or(ShiftRightSame(v, 8), ShiftLeftSame(v, 8));
        StoreU(vswap, du, tmp + j);
      }
    }
    memcpy(output, tmp, len * num_channels * 2);
  } else if (m->output_data_type_ == JPEGLI_TYPE_FLOAT) {
    float* tmp = reinterpret_cast<float*>(scratch_space);
    StoreFloatRow(rows, xoffset, len, num_channels, tmp);
    if (m->swap_endianness_) {
      size_t output_len = len * num_channels;
      for (size_t j = 0; j < output_len; ++j) {
        tmp[j] = BSwapFloat(tmp[j]);
      }
    }
    memcpy(output, tmp, len * num_channels * 4);
  }
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jpegli
HWY_AFTER_NAMESPACE();

#if HWY_ONCE

namespace jpegli {

HWY_EXPORT(GatherBlockStats);
HWY_EXPORT(WriteToOutput);
HWY_EXPORT(DecenterRow);

void GatherBlockStats(const int16_t* JXL_RESTRICT coeffs,
                      const size_t coeffs_size, int32_t* JXL_RESTRICT nonzeros,
                      int32_t* JXL_RESTRICT sumabs) {
  return HWY_DYNAMIC_DISPATCH(GatherBlockStats)(coeffs, coeffs_size, nonzeros,
                                                sumabs);
}

void WriteToOutput(j_decompress_ptr cinfo, float* JXL_RESTRICT rows[],
                   size_t xoffset, size_t len, size_t num_channels,
                   uint8_t* JXL_RESTRICT output) {
  return HWY_DYNAMIC_DISPATCH(WriteToOutput)(cinfo, rows, xoffset, len,
                                             num_channels, output);
}

void DecenterRow(float* row, size_t xsize) {
  return HWY_DYNAMIC_DISPATCH(DecenterRow)(row, xsize);
}

bool ShouldApplyDequantBiases(j_decompress_ptr cinfo, int ci) {
  const auto& compinfo = cinfo->comp_info[ci];
  return (compinfo.h_samp_factor == cinfo->max_h_samp_factor &&
          compinfo.v_samp_factor == cinfo->max_v_samp_factor);
}

// See the following article for the details:
// J. R. Price and M. Rabbani, "Dequantization bias for JPEG decompression"
// Proceedings International Conference on Information Technology: Coding and
// Computing (Cat. No.PR00540), 2000, pp. 30-35, doi: 10.1109/ITCC.2000.844179.
void ComputeOptimalLaplacianBiases(const int num_blocks, const int* nonzeros,
                                   const int* sumabs, float* biases) {
  for (size_t k = 1; k < DCTSIZE2; ++k) {
    if (nonzeros[k] == 0) {
      biases[k] = 0.5f;
      continue;
    }
    // Notation adapted from the article
    float N = num_blocks;
    float N1 = nonzeros[k];
    float N0 = num_blocks - N1;
    float S = sumabs[k];
    // Compute gamma from N0, N1, N, S (eq. 11), with A and B being just
    // temporary grouping of terms.
    float A = 4.0 * S + 2.0 * N;
    float B = 4.0 * S - 2.0 * N1;
    float gamma = (-1.0 * N0 + std::sqrt(N0 * N0 * 1.0 + A * B)) / A;
    float gamma2 = gamma * gamma;
    // The bias is computed from gamma with (eq. 5), where the quantization
    // multiplier Q can be factored out and thus the bias can be applied
    // directly on the quantized coefficient.
    biases[k] =
        0.5 * (((1.0 + gamma2) / (1.0 - gamma2)) + 1.0 / std::log(gamma));
  }
}

constexpr std::array<int, SAVED_COEFS> Q_POS = {0, 1, 8,  16, 9,
                                                2, 3, 10, 17, 24};

bool is_nonzero_quantizers(const JQUANT_TBL* qtable) {
  return std::all_of(Q_POS.begin(), Q_POS.end(),
                     [&](int pos) { return qtable->quantval[pos] != 0; });
}

// Determine whether smoothing should be applied during decompression
bool do_smoothing(j_decompress_ptr cinfo) {
  jpeg_decomp_master* m = cinfo->master;
  bool smoothing_useful = false;

  if (!cinfo->progressive_mode || cinfo->coef_bits == nullptr) {
    return false;
  }
  auto coef_bits_latch = m->coef_bits_latch;
  auto prev_coef_bits_latch = m->prev_coef_bits_latch;

  for (int ci = 0; ci < cinfo->num_components; ci++) {
    jpeg_component_info* compptr = &cinfo->comp_info[ci];
    JQUANT_TBL* qtable = compptr->quant_table;
    int* coef_bits = cinfo->coef_bits[ci];
    int* prev_coef_bits = cinfo->coef_bits[ci + cinfo->num_components];

    // Return early if conditions for smoothing are not met
    if (qtable == nullptr || !is_nonzero_quantizers(qtable) ||
        coef_bits[0] < 0) {
      return false;
    }

    coef_bits_latch[ci][0] = coef_bits[0];

    for (int coefi = 1; coefi < SAVED_COEFS; coefi++) {
      prev_coef_bits_latch[ci][coefi] =
          cinfo->input_scan_number > 1 ? prev_coef_bits[coefi] : -1;
      if (coef_bits[coefi] != 0) {
        smoothing_useful = true;
      }
      coef_bits_latch[ci][coefi] = coef_bits[coefi];
    }
  }

  return smoothing_useful;
}

void PredictSmooth(j_decompress_ptr cinfo, JBLOCKARRAY blocks, int component,
                   size_t bx, int iy) {
  const size_t imcu_row = cinfo->output_iMCU_row;
  int16_t* scratch = cinfo->master->smoothing_scratch_;
  std::vector<int> Q_VAL(SAVED_COEFS);
  int* coef_bits;

  std::array<std::array<int, 5>, 5> dc_values;
  auto& compinfo = cinfo->comp_info[component];
  const size_t by0 = imcu_row * compinfo.v_samp_factor;
  const size_t by = by0 + iy;

  int prev_iy = by > 0 ? iy - 1 : 0;
  int prev_prev_iy = by > 1 ? iy - 2 : prev_iy;
  int next_iy = by + 1 < compinfo.height_in_blocks ? iy + 1 : iy;
  int next_next_iy = by + 2 < compinfo.height_in_blocks ? iy + 2 : next_iy;

  const int16_t* cur_row = blocks[iy][bx];
  const int16_t* prev_row = blocks[prev_iy][bx];
  const int16_t* prev_prev_row = blocks[prev_prev_iy][bx];
  const int16_t* next_row = blocks[next_iy][bx];
  const int16_t* next_next_row = blocks[next_next_iy][bx];

  int prev_block_ind = bx ? -DCTSIZE2 : 0;
  int prev_prev_block_ind = bx > 1 ? -2 * DCTSIZE2 : prev_block_ind;
  int next_block_ind = bx + 1 < compinfo.width_in_blocks ? DCTSIZE2 : 0;
  int next_next_block_ind =
      bx + 2 < compinfo.width_in_blocks ? DCTSIZE2 * 2 : next_block_ind;

  std::array<const int16_t*, 5> row_ptrs = {prev_prev_row, prev_row, cur_row,
                                            next_row, next_next_row};
  std::array<int, 5> block_inds = {prev_prev_block_ind, prev_block_ind, 0,
                                   next_block_ind, next_next_block_ind};

  memcpy(scratch, cur_row, DCTSIZE2 * sizeof(cur_row[0]));

  for (int r = 0; r < 5; ++r) {
    for (int c = 0; c < 5; ++c) {
      dc_values[r][c] = row_ptrs[r][block_inds[c]];
    }
  }
  // Get the correct coef_bits: In case of an incomplete scan, we use the
  // prev coeficients.
  if (cinfo->output_iMCU_row + 1 > cinfo->input_iMCU_row) {
    coef_bits = cinfo->master->prev_coef_bits_latch[component];
  } else {
    coef_bits = cinfo->master->coef_bits_latch[component];
  }

  bool change_dc = true;
  for (int i = 1; i < SAVED_COEFS; i++) {
    if (coef_bits[i] != -1) {
      change_dc = false;
      break;
    }
  }

  JQUANT_TBL* quanttbl = cinfo->quant_tbl_ptrs[compinfo.quant_tbl_no];
  for (size_t i = 0; i < 6; ++i) {
    Q_VAL[i] = quanttbl->quantval[Q_POS[i]];
  }
  if (change_dc) {
    for (size_t i = 6; i < SAVED_COEFS; ++i) {
      Q_VAL[i] = quanttbl->quantval[Q_POS[i]];
    }
  }
  auto calculate_dct_value = [&](int coef_index) {
    int64_t num = 0;
    int pred;
    int Al;
    // we use the symmetry of the smoothing matrices by transposing the 5x5 dc
    // matrix in that case.
    bool swap_indices = coef_index == 2 || coef_index == 5 || coef_index == 8 ||
                        coef_index == 9;
    auto dc = [&](int i, int j) {
      return swap_indices ? dc_values[j][i] : dc_values[i][j];
    };
    Al = coef_bits[coef_index];
    switch (coef_index) {
      case 0:
        // set the DC
        num = (-2 * dc(0, 0) - 6 * dc(0, 1) - 8 * dc(0, 2) - 6 * dc(0, 3) -
               2 * dc(0, 4) - 6 * dc(1, 0) + 6 * dc(1, 1) + 42 * dc(1, 2) +
               6 * dc(1, 3) - 6 * dc(1, 4) - 8 * dc(2, 0) + 42 * dc(2, 1) +
               152 * dc(2, 2) + 42 * dc(2, 3) - 8 * dc(2, 4) - 6 * dc(3, 0) +
               6 * dc(3, 1) + 42 * dc(3, 2) + 6 * dc(3, 3) - 6 * dc(3, 4) -
               2 * dc(4, 0) - 6 * dc(4, 1) - 8 * dc(4, 2) - 6 * dc(4, 3) -
               2 * dc(4, 4));
        // special case: for the DC the dequantization is different
        Al = 0;
        break;
      case 1:
      case 2:
        // set Q01 or Q10
        num = (change_dc ? (-dc(0, 0) - dc(0, 1) + dc(0, 3) + dc(0, 4) -
                            3 * dc(1, 0) + 13 * dc(1, 1) - 13 * dc(1, 3) +
                            3 * dc(1, 4) - 3 * dc(2, 0) + 38 * dc(2, 1) -
                            38 * dc(2, 3) + 3 * dc(2, 4) - 3 * dc(3, 0) +
                            13 * dc(3, 1) - 13 * dc(3, 3) + 3 * dc(3, 4) -
                            dc(4, 0) - dc(4, 1) + dc(4, 3) + dc(4, 4))
                         : (-7 * dc(2, 0) + 50 * dc(2, 1) - 50 * dc(2, 3) +
                            7 * dc(2, 4)));
        break;
      case 3:
      case 5:
        // set Q02 or Q20
        num = (change_dc
                   ? dc(0, 2) + 2 * dc(1, 1) + 7 * dc(1, 2) + 2 * dc(1, 3) -
                         5 * dc(2, 1) - 14 * dc(2, 2) - 5 * dc(2, 3) +
                         2 * dc(3, 1) + 7 * dc(3, 2) + 2 * dc(3, 3) + dc(4, 2)
                   : (-dc(0, 2) + 13 * dc(1, 2) - 24 * dc(2, 2) +
                      13 * dc(3, 2) - dc(4, 2)));
        break;
      case 4:
        // set Q11
        num =
            (change_dc ? -dc(0, 0) + dc(0, 4) + 9 * dc(1, 1) - 9 * dc(1, 3) -
                             9 * dc(3, 1) + 9 * dc(3, 3) + dc(4, 0) - dc(4, 4)
                       : (dc(1, 4) + dc(3, 0) - 10 * dc(3, 1) + 10 * dc(3, 3) -
                          dc(0, 1) - dc(3, 4) + dc(4, 1) - dc(4, 3) + dc(0, 3) -
                          dc(1, 0) + 10 * dc(1, 1) - 10 * dc(1, 3)));
        break;
      case 6:
      case 9:
        // set Q03 or Q30
        num = (dc(1, 1) - dc(1, 3) + 2 * dc(2, 1) - 2 * dc(2, 3) + dc(3, 1) -
               dc(3, 3));
        break;
      case 7:
      case 8:
        // set Q12 and Q21
        num = (dc(1, 1) - 3 * dc(1, 2) + dc(1, 3) - dc(3, 1) + 3 * dc(3, 2) -
               dc(3, 3));
        break;
    }
    num = Q_VAL[0] * num;
    if (num >= 0) {
      pred = ((Q_VAL[coef_index] << 7) + num) / (Q_VAL[coef_index] << 8);
      if (Al > 0 && pred >= (1 << Al)) pred = (1 << Al) - 1;
    } else {
      pred = ((Q_VAL[coef_index] << 7) - num) / (Q_VAL[coef_index] << 8);
      if (Al > 0 && pred >= (1 << Al)) pred = (1 << Al) - 1;
      pred = -pred;
    }
    return static_cast<int16_t>(pred);
  };

  int loop_end = change_dc ? SAVED_COEFS : 6;
  for (int i = 1; i < loop_end; ++i) {
    if (coef_bits[i] != 0 && scratch[Q_POS[i]] == 0) {
      scratch[Q_POS[i]] = calculate_dct_value(i);
    }
  }
  if (change_dc) {
    scratch[0] = calculate_dct_value(0);
  }
}

void PrepareForOutput(j_decompress_ptr cinfo) {
  jpeg_decomp_master* m = cinfo->master;
  bool smoothing = do_smoothing(cinfo);
  m->apply_smoothing = smoothing && cinfo->do_block_smoothing;
  size_t coeffs_per_block = cinfo->num_components * DCTSIZE2;
  memset(m->nonzeros_, 0, coeffs_per_block * sizeof(m->nonzeros_[0]));
  memset(m->sumabs_, 0, coeffs_per_block * sizeof(m->sumabs_[0]));
  memset(m->num_processed_blocks_, 0, sizeof(m->num_processed_blocks_));
  memset(m->biases_, 0, coeffs_per_block * sizeof(m->biases_[0]));
  cinfo->output_iMCU_row = 0;
  cinfo->output_scanline = 0;
  const float kDequantScale = 1.0f / (8 * 255);
  for (int c = 0; c < cinfo->num_components; c++) {
    const auto& comp = cinfo->comp_info[c];
    JQUANT_TBL* table = comp.quant_table;
    if (table == nullptr) continue;
    for (size_t k = 0; k < DCTSIZE2; ++k) {
      m->dequant_[c * DCTSIZE2 + k] = table->quantval[k] * kDequantScale;
    }
  }
  ChooseInverseTransform(cinfo);
  ChooseColorTransform(cinfo);
}

void DecodeCurrentiMCURow(j_decompress_ptr cinfo) {
  jpeg_decomp_master* m = cinfo->master;
  const size_t imcu_row = cinfo->output_iMCU_row;
  JBLOCKARRAY ba[kMaxComponents];
  for (int c = 0; c < cinfo->num_components; ++c) {
    const jpeg_component_info* comp = &cinfo->comp_info[c];
    int by0 = imcu_row * comp->v_samp_factor;
    int block_rows_left = comp->height_in_blocks - by0;
    int max_block_rows = std::min(comp->v_samp_factor, block_rows_left);
    int offset = m->streaming_mode_ ? 0 : by0;
    ba[c] = (*cinfo->mem->access_virt_barray)(
        reinterpret_cast<j_common_ptr>(cinfo), m->coef_arrays[c], offset,
        max_block_rows, false);
  }
  for (int c = 0; c < cinfo->num_components; ++c) {
    size_t k0 = c * DCTSIZE2;
    auto& compinfo = cinfo->comp_info[c];
    size_t block_row = imcu_row * compinfo.v_samp_factor;
    if (ShouldApplyDequantBiases(cinfo, c)) {
      // Update statistics for this iMCU row.
      for (int iy = 0; iy < compinfo.v_samp_factor; ++iy) {
        size_t by = block_row + iy;
        if (by >= compinfo.height_in_blocks) {
          continue;
        }
        int16_t* JXL_RESTRICT coeffs = &ba[c][iy][0][0];
        size_t num = compinfo.width_in_blocks * DCTSIZE2;
        GatherBlockStats(coeffs, num, &m->nonzeros_[k0], &m->sumabs_[k0]);
        m->num_processed_blocks_[c] += compinfo.width_in_blocks;
      }
      if (imcu_row % 4 == 3) {
        // Re-compute optimal biases every few iMCU-rows.
        ComputeOptimalLaplacianBiases(m->num_processed_blocks_[c],
                                      &m->nonzeros_[k0], &m->sumabs_[k0],
                                      &m->biases_[k0]);
      }
    }
    RowBuffer<float>* raw_out = &m->raw_output_[c];
    for (int iy = 0; iy < compinfo.v_samp_factor; ++iy) {
      size_t by = block_row + iy;
      if (by >= compinfo.height_in_blocks) {
        continue;
      }
      size_t dctsize = m->scaled_dct_size[c];
      int16_t* JXL_RESTRICT row_in = &ba[c][iy][0][0];
      float* JXL_RESTRICT row_out = raw_out->Row(by * dctsize);
      for (size_t bx = 0; bx < compinfo.width_in_blocks; ++bx) {
        if (m->apply_smoothing) {
          PredictSmooth(cinfo, ba[c], c, bx, iy);
          (*m->inverse_transform[c])(m->smoothing_scratch_, &m->dequant_[k0],
                                     &m->biases_[k0], m->idct_scratch_,
                                     &row_out[bx * dctsize], raw_out->stride(),
                                     dctsize);
        } else {
          (*m->inverse_transform[c])(&row_in[bx * DCTSIZE2], &m->dequant_[k0],
                                     &m->biases_[k0], m->idct_scratch_,
                                     &row_out[bx * dctsize], raw_out->stride(),
                                     dctsize);
        }
      }
      if (m->streaming_mode_) {
        memset(row_in, 0, compinfo.width_in_blocks * sizeof(JBLOCK));
      }
    }
  }
}

void ProcessRawOutput(j_decompress_ptr cinfo, JSAMPIMAGE data) {
  jpegli::DecodeCurrentiMCURow(cinfo);
  jpeg_decomp_master* m = cinfo->master;
  for (int c = 0; c < cinfo->num_components; ++c) {
    const auto& compinfo = cinfo->comp_info[c];
    size_t comp_width = compinfo.width_in_blocks * DCTSIZE;
    size_t comp_height = compinfo.height_in_blocks * DCTSIZE;
    size_t comp_nrows = compinfo.v_samp_factor * DCTSIZE;
    size_t y0 = cinfo->output_iMCU_row * compinfo.v_samp_factor * DCTSIZE;
    size_t y1 = std::min(y0 + comp_nrows, comp_height);
    for (size_t y = y0; y < y1; ++y) {
      float* rows[1] = {m->raw_output_[c].Row(y)};
      uint8_t* output = data[c][y - y0];
      DecenterRow(rows[0], comp_width);
      WriteToOutput(cinfo, rows, 0, comp_width, 1, output);
    }
  }
  ++cinfo->output_iMCU_row;
  cinfo->output_scanline += cinfo->max_v_samp_factor * DCTSIZE;
  if (cinfo->output_scanline >= cinfo->output_height) {
    ++m->output_passes_done_;
  }
}

void ProcessOutput(j_decompress_ptr cinfo, size_t* num_output_rows,
                   JSAMPARRAY scanlines, size_t max_output_rows) {
  jpeg_decomp_master* m = cinfo->master;
  const int vfactor = cinfo->max_v_samp_factor;
  const int hfactor = cinfo->max_h_samp_factor;
  const size_t context = m->need_context_rows_ ? 1 : 0;
  const size_t imcu_row = cinfo->output_iMCU_row;
  const size_t imcu_height = vfactor * m->min_scaled_dct_size;
  const size_t imcu_width = hfactor * m->min_scaled_dct_size;
  const size_t output_width = m->iMCU_cols_ * imcu_width;
  if (imcu_row == cinfo->total_iMCU_rows ||
      (imcu_row > context &&
       cinfo->output_scanline < (imcu_row - context) * imcu_height)) {
    // We are ready to output some scanlines.
    size_t ybegin = cinfo->output_scanline;
    size_t yend = (imcu_row == cinfo->total_iMCU_rows
                       ? cinfo->output_height
                       : (imcu_row - context) * imcu_height);
    yend = std::min<size_t>(yend, ybegin + max_output_rows - *num_output_rows);
    size_t yb = (ybegin / vfactor) * vfactor;
    size_t ye = DivCeil(yend, vfactor) * vfactor;
    for (size_t y = yb; y < ye; y += vfactor) {
      for (int c = 0; c < cinfo->num_components; ++c) {
        RowBuffer<float>* raw_out = &m->raw_output_[c];
        RowBuffer<float>* render_out = &m->render_output_[c];
        int line_groups = vfactor / m->v_factor[c];
        int downsampled_width = output_width / m->h_factor[c];
        size_t yc = y / m->v_factor[c];
        for (int dy = 0; dy < line_groups; ++dy) {
          size_t ymid = yc + dy;
          const float* JXL_RESTRICT row_mid = raw_out->Row(ymid);
          if (cinfo->do_fancy_upsampling && m->v_factor[c] == 2) {
            const float* JXL_RESTRICT row_top =
                ymid == 0 ? row_mid : raw_out->Row(ymid - 1);
            const float* JXL_RESTRICT row_bot = ymid + 1 == m->raw_height_[c]
                                                    ? row_mid
                                                    : raw_out->Row(ymid + 1);
            Upsample2Vertical(row_top, row_mid, row_bot,
                              render_out->Row(2 * dy),
                              render_out->Row(2 * dy + 1), downsampled_width);
          } else {
            for (int yix = 0; yix < m->v_factor[c]; ++yix) {
              memcpy(render_out->Row(m->v_factor[c] * dy + yix), row_mid,
                     downsampled_width * sizeof(float));
            }
          }
          if (m->h_factor[c] > 1) {
            for (int yix = 0; yix < m->v_factor[c]; ++yix) {
              int row_ix = m->v_factor[c] * dy + yix;
              float* JXL_RESTRICT row = render_out->Row(row_ix);
              float* JXL_RESTRICT tmp = m->upsample_scratch_;
              if (cinfo->do_fancy_upsampling && m->h_factor[c] == 2) {
                Upsample2Horizontal(row, tmp, output_width);
              } else {
                // TODO(szabadka) SIMDify this.
                for (size_t x = 0; x < output_width; ++x) {
                  tmp[x] = row[x / m->h_factor[c]];
                }
                memcpy(row, tmp, output_width * sizeof(tmp[0]));
              }
            }
          }
        }
      }
      for (int yix = 0; yix < vfactor; ++yix) {
        if (y + yix < ybegin || y + yix >= yend) continue;
        float* rows[kMaxComponents];
        int num_all_components =
            std::max(cinfo->out_color_components, cinfo->num_components);
        for (int c = 0; c < num_all_components; ++c) {
          rows[c] = m->render_output_[c].Row(yix);
        }
        (*m->color_transform)(rows, output_width);
        for (int c = 0; c < cinfo->out_color_components; ++c) {
          // Undo the centering of the sample values around zero.
          DecenterRow(rows[c], output_width);
        }
        if (scanlines) {
          uint8_t* output = scanlines[*num_output_rows];
          WriteToOutput(cinfo, rows, m->xoffset_, cinfo->output_width,
                        cinfo->out_color_components, output);
        }
        JXL_ASSERT(cinfo->output_scanline == y + yix);
        ++cinfo->output_scanline;
        ++(*num_output_rows);
        if (cinfo->output_scanline == cinfo->output_height) {
          ++m->output_passes_done_;
        }
      }
    }
  } else {
    DecodeCurrentiMCURow(cinfo);
    ++cinfo->output_iMCU_row;
  }
}

}  // namespace jpegli
#endif  // HWY_ONCE
