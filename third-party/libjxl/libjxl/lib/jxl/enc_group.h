// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_GROUP_H_
#define LIB_JXL_ENC_GROUP_H_

#include <stddef.h>
#include <stdint.h>

#include "lib/jxl/base/status.h"
#include "lib/jxl/enc_bit_writer.h"
#include "lib/jxl/image.h"

namespace jxl {

struct AuxOut;
struct PassesEncoderState;

// Fills DC
void ComputeCoefficients(size_t group_idx, PassesEncoderState* enc_state,
                         const Image3F& opsin, Image3F* dc);

Status EncodeGroupTokenizedCoefficients(size_t group_idx, size_t pass_idx,
                                        size_t histogram_idx,
                                        const PassesEncoderState& enc_state,
                                        BitWriter* writer, AuxOut* aux_out);

}  // namespace jxl

#endif  // LIB_JXL_ENC_GROUP_H_
