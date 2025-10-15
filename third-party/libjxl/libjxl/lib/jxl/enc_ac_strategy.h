// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_AC_STRATEGY_H_
#define LIB_JXL_ENC_AC_STRATEGY_H_

#include <stdint.h>

#include "lib/jxl/ac_strategy.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/common.h"
#include "lib/jxl/dec_ans.h"
#include "lib/jxl/enc_cache.h"
#include "lib/jxl/enc_params.h"
#include "lib/jxl/image.h"
#include "lib/jxl/quant_weights.h"

// `FindBestAcStrategy` uses heuristics to choose which AC strategy should be
// used in each block, as well as the initial quantization field.

namespace jxl {

struct AuxOut;

// AC strategy selection: utility struct.

struct ACSConfig {
  const DequantMatrices* JXL_RESTRICT dequant;
  float info_loss_multiplier;
  float info_loss_multiplier2;
  float* JXL_RESTRICT quant_field_row;
  size_t quant_field_stride;
  float* JXL_RESTRICT masking_field_row;
  size_t masking_field_stride;
  const float* JXL_RESTRICT src_rows[3];
  size_t src_stride;
  float cost_delta;
  float zeros_mul;
  const float& Pixel(size_t c, size_t x, size_t y) const {
    return src_rows[c][y * src_stride + x];
  }
  float Masking(size_t bx, size_t by) const {
    JXL_DASSERT(masking_field_row[by * masking_field_stride + bx] > 0);
    return masking_field_row[by * masking_field_stride + bx];
  }
  float Quant(size_t bx, size_t by) const {
    JXL_DASSERT(quant_field_row[by * quant_field_stride + bx] > 0);
    return quant_field_row[by * quant_field_stride + bx];
  }
};

struct AcStrategyHeuristics {
  void Init(const Image3F& src, PassesEncoderState* enc_state);
  void ProcessRect(const Rect& rect);
  void Finalize(AuxOut* aux_out);
  ACSConfig config;
  PassesEncoderState* enc_state;
};

}  // namespace jxl

#endif  // LIB_JXL_ENC_AC_STRATEGY_H_
