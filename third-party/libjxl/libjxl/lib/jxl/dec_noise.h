// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_DEC_NOISE_H_
#define LIB_JXL_DEC_NOISE_H_

// Noise synthesis. Currently disabled.

#include <stddef.h>
#include <stdint.h>

#include "lib/jxl/base/status.h"
#include "lib/jxl/chroma_from_luma.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/image.h"
#include "lib/jxl/noise.h"

namespace jxl {

void Random3Planes(size_t visible_frame_index, size_t nonvisible_frame_index,
                   size_t x0, size_t y0, const std::pair<ImageF*, Rect>& plane0,
                   const std::pair<ImageF*, Rect>& plane1,
                   const std::pair<ImageF*, Rect>& plane2);

// Must only call if FrameHeader.flags.kNoise.
Status DecodeNoise(BitReader* br, NoiseParams* noise_params);

}  // namespace jxl

#endif  // LIB_JXL_DEC_NOISE_H_
