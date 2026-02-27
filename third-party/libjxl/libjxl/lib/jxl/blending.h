// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_BLENDING_H_
#define LIB_JXL_BLENDING_H_
#include "lib/jxl/dec_cache.h"
#include "lib/jxl/dec_patch_dictionary.h"
#include "lib/jxl/image_bundle.h"

namespace jxl {

bool NeedsBlending(PassesDecoderState* dec_state);

void PerformBlending(const float* const* bg, const float* const* fg,
                     float* const* out, size_t x0, size_t xsize,
                     const PatchBlending& color_blending,
                     const PatchBlending* ec_blending,
                     const std::vector<ExtraChannelInfo>& extra_channel_info);

}  // namespace jxl

#endif  // LIB_JXL_BLENDING_H_
