#pragma once

#include <cstdint>
#include <cstddef>
#include <vector>
#include "types.h"
#include "mbs_format.h"

namespace subcodec::mbs {

MbsEncodedFrame encode_frame(
    const FrameParams& params,
    const MacroblockData* mbs);

// Encode color and alpha halves into a single frame with pre-merged row blobs.
// color_params/color_mbs: color half MacroblockData (padded sprite dimensions).
// alpha_params/alpha_mbs: alpha half MacroblockData (same dimensions).
// sprite_w: padded sprite width in MBs. padding: always 1.
// Returns MbsEncodedFrame with merged rows (no separate alpha_rows).
MbsEncodedFrame encode_frame_merged(
    const FrameParams& color_params, const MacroblockData* color_mbs,
    const FrameParams& alpha_params, const MacroblockData* alpha_mbs,
    int sprite_w, int padding);

} // namespace subcodec::mbs
