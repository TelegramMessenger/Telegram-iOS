// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/passes_state.h"

#include "lib/jxl/chroma_from_luma.h"
#include "lib/jxl/coeff_order.h"
#include "lib/jxl/common.h"

namespace jxl {

Status InitializePassesSharedState(const FrameHeader& frame_header,
                                   PassesSharedState* JXL_RESTRICT shared,
                                   bool encoder) {
  JXL_ASSERT(frame_header.nonserialized_metadata != nullptr);
  shared->frame_header = frame_header;
  shared->metadata = frame_header.nonserialized_metadata;
  shared->frame_dim = frame_header.ToFrameDimensions();
  shared->image_features.patches.SetPassesSharedState(shared);

  const FrameDimensions& frame_dim = shared->frame_dim;

  shared->ac_strategy =
      AcStrategyImage(frame_dim.xsize_blocks, frame_dim.ysize_blocks);
  shared->raw_quant_field =
      ImageI(frame_dim.xsize_blocks, frame_dim.ysize_blocks);
  shared->epf_sharpness =
      ImageB(frame_dim.xsize_blocks, frame_dim.ysize_blocks);
  shared->cmap = ColorCorrelationMap(frame_dim.xsize, frame_dim.ysize);

  // In the decoder, we allocate coeff orders afterwards, when we know how many
  // we will actually need.
  shared->coeff_order_size = kCoeffOrderMaxSize;
  if (encoder &&
      shared->coeff_orders.size() <
          frame_header.passes.num_passes * kCoeffOrderMaxSize &&
      frame_header.encoding == FrameEncoding::kVarDCT) {
    shared->coeff_orders.resize(frame_header.passes.num_passes *
                                kCoeffOrderMaxSize);
  }

  shared->quant_dc = ImageB(frame_dim.xsize_blocks, frame_dim.ysize_blocks);

  bool use_dc_frame = !!(frame_header.flags & FrameHeader::kUseDcFrame);
  if (!encoder && use_dc_frame) {
    if (frame_header.dc_level == 4) {
      return JXL_FAILURE("Invalid DC level for kUseDcFrame: %u",
                         frame_header.dc_level);
    }
    shared->dc_storage = Image3F();
    shared->dc = &shared->dc_frames[frame_header.dc_level];
    if (shared->dc->xsize() == 0) {
      return JXL_FAILURE(
          "kUseDcFrame specified for dc_level %u, but no frame was decoded "
          "with level %u",
          frame_header.dc_level, frame_header.dc_level + 1);
    }
    ZeroFillImage(&shared->quant_dc);
  } else {
    shared->dc_storage =
        Image3F(frame_dim.xsize_blocks, frame_dim.ysize_blocks);
    shared->dc = &shared->dc_storage;
  }

  return true;
}

}  // namespace jxl
