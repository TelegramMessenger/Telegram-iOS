// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_QUANT_WEIGHTS_H_
#define LIB_JXL_ENC_QUANT_WEIGHTS_H_

#include "lib/jxl/quant_weights.h"

namespace jxl {

struct AuxOut;
struct BitWriter;

Status DequantMatricesEncode(
    const DequantMatrices* matrices, BitWriter* writer, size_t layer,
    AuxOut* aux_out, ModularFrameEncoder* modular_frame_encoder = nullptr);
Status DequantMatricesEncodeDC(const DequantMatrices* matrices,
                               BitWriter* writer, size_t layer,
                               AuxOut* aux_out);
// For consistency with QuantEncoding, higher values correspond to more
// precision.
void DequantMatricesSetCustomDC(DequantMatrices* matrices, const float* dc);

void DequantMatricesScaleDC(DequantMatrices* matrices, float scale);

void DequantMatricesSetCustom(DequantMatrices* matrices,
                              const std::vector<QuantEncoding>& encodings,
                              ModularFrameEncoder* encoder);

// Roundtrip encode/decode the matrices to ensure same values as decoder.
void DequantMatricesRoundtrip(DequantMatrices* matrices);

}  // namespace jxl

#endif  // LIB_JXL_ENC_QUANT_WEIGHTS_H_
