// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_RENDER_PIPELINE_STAGE_BLENDING_H_
#define LIB_JXL_RENDER_PIPELINE_STAGE_BLENDING_H_

#include <utility>

#include "lib/jxl/dec_cache.h"
#include "lib/jxl/render_pipeline/render_pipeline_stage.h"
#include "lib/jxl/splines.h"

namespace jxl {

// Applies blending if applicable.
std::unique_ptr<RenderPipelineStage> GetBlendingStage(
    const PassesDecoderState* dec_state,
    const ColorEncoding& frame_color_encoding);

}  // namespace jxl

#endif  // LIB_JXL_RENDER_PIPELINE_STAGE_BLENDING_H_
