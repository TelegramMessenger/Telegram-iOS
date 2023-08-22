// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_DEC_GROUP_H_
#define LIB_JXL_DEC_GROUP_H_

#include <stddef.h>
#include <stdint.h>

#include <vector>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/chroma_from_luma.h"
#include "lib/jxl/coeff_order_fwd.h"
#include "lib/jxl/dct_util.h"
#include "lib/jxl/dec_ans.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/dec_cache.h"
#include "lib/jxl/frame_header.h"
#include "lib/jxl/image.h"
#include "lib/jxl/quantizer.h"

namespace jxl {

struct AuxOut;

Status DecodeGroup(BitReader* JXL_RESTRICT* JXL_RESTRICT readers,
                   size_t num_passes, size_t group_idx,
                   PassesDecoderState* JXL_RESTRICT dec_state,
                   GroupDecCache* JXL_RESTRICT group_dec_cache, size_t thread,
                   RenderPipelineInput& render_pipeline_input,
                   ImageBundle* JXL_RESTRICT decoded, size_t first_pass,
                   bool force_draw, bool dc_only, bool* should_run_pipeline);

Status DecodeGroupForRoundtrip(const std::vector<std::unique_ptr<ACImage>>& ac,
                               size_t group_idx,
                               PassesDecoderState* JXL_RESTRICT dec_state,
                               GroupDecCache* JXL_RESTRICT group_dec_cache,
                               size_t thread,
                               RenderPipelineInput& render_pipeline_input,
                               ImageBundle* JXL_RESTRICT decoded,
                               AuxOut* aux_out);

}  // namespace jxl

#endif  // LIB_JXL_DEC_GROUP_H_
