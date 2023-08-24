// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_CHROMA_FROM_LUMA_H_
#define LIB_JXL_ENC_CHROMA_FROM_LUMA_H_

// Chroma-from-luma, computed using heuristics to determine the best linear
// model for the X and B channels from the Y channel.

#include <stddef.h>
#include <stdint.h>

#include <vector>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/chroma_from_luma.h"
#include "lib/jxl/common.h"
#include "lib/jxl/dec_ans.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/enc_ans.h"
#include "lib/jxl/enc_bit_writer.h"
#include "lib/jxl/entropy_coder.h"
#include "lib/jxl/field_encodings.h"
#include "lib/jxl/fields.h"
#include "lib/jxl/image.h"
#include "lib/jxl/opsin_params.h"
#include "lib/jxl/quant_weights.h"

namespace jxl {

struct AuxOut;
class Quantizer;

void ColorCorrelationMapEncodeDC(ColorCorrelationMap* map, BitWriter* writer,
                                 size_t layer, AuxOut* aux_out);

struct CfLHeuristics {
  void Init(const Image3F& opsin);

  void PrepareForThreads(size_t num_threads) {
    mem = hwy::AllocateAligned<float>(num_threads * kItemsPerThread);
  }

  void ComputeTile(const Rect& r, const Image3F& opsin,
                   const DequantMatrices& dequant,
                   const AcStrategyImage* ac_strategy,
                   const ImageI* raw_quant_field, const Quantizer* quantizer,
                   bool fast, size_t thread, ColorCorrelationMap* cmap);

  void ComputeDC(bool fast, ColorCorrelationMap* cmap);

  ImageF dc_values;
  hwy::AlignedFreeUniquePtr<float[]> mem;

  // Working set is too large for stack; allocate dynamically.
  constexpr static size_t kItemsPerThread =
      AcStrategy::kMaxCoeffArea * 3        // Blocks
      + kColorTileDim * kColorTileDim * 4  // AC coeff storage
      + AcStrategy::kMaxCoeffArea * 2;     // Scratch space
};

}  // namespace jxl

#endif  // LIB_JXL_ENC_CHROMA_FROM_LUMA_H_
