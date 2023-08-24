// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/blending.h"

#include "lib/jxl/alpha.h"
#include "lib/jxl/image_ops.h"

namespace jxl {

bool NeedsBlending(PassesDecoderState* dec_state) {
  const PassesSharedState& state = *dec_state->shared;
  if (!(state.frame_header.frame_type == FrameType::kRegularFrame ||
        state.frame_header.frame_type == FrameType::kSkipProgressive)) {
    return false;
  }
  const auto& info = state.frame_header.blending_info;
  bool replace_all = (info.mode == BlendMode::kReplace);
  for (const auto& ec_i : state.frame_header.extra_channel_blending_info) {
    if (ec_i.mode != BlendMode::kReplace) {
      replace_all = false;
    }
  }
  // Replace the full frame: nothing to do.
  if (!state.frame_header.custom_size_or_origin && replace_all) {
    return false;
  }
  return true;
}

void PerformBlending(const float* const* bg, const float* const* fg,
                     float* const* out, size_t x0, size_t xsize,
                     const PatchBlending& color_blending,
                     const PatchBlending* ec_blending,
                     const std::vector<ExtraChannelInfo>& extra_channel_info) {
  bool has_alpha = false;
  size_t num_ec = extra_channel_info.size();
  for (size_t i = 0; i < num_ec; i++) {
    if (extra_channel_info[i].type == jxl::ExtraChannel::kAlpha) {
      has_alpha = true;
      break;
    }
  }
  ImageF tmp(xsize, 3 + num_ec);
  // Blend extra channels first so that we use the pre-blending alpha.
  for (size_t i = 0; i < num_ec; i++) {
    if (ec_blending[i].mode == PatchBlendMode::kAdd) {
      for (size_t x = 0; x < xsize; x++) {
        tmp.Row(3 + i)[x] = bg[3 + i][x + x0] + fg[3 + i][x + x0];
      }
    } else if (ec_blending[i].mode == PatchBlendMode::kBlendAbove) {
      size_t alpha = ec_blending[i].alpha_channel;
      bool is_premultiplied = extra_channel_info[alpha].alpha_associated;
      PerformAlphaBlending(bg[3 + i] + x0, bg[3 + alpha] + x0, fg[3 + i] + x0,
                           fg[3 + alpha] + x0, tmp.Row(3 + i), xsize,
                           is_premultiplied, ec_blending[i].clamp);
    } else if (ec_blending[i].mode == PatchBlendMode::kBlendBelow) {
      size_t alpha = ec_blending[i].alpha_channel;
      bool is_premultiplied = extra_channel_info[alpha].alpha_associated;
      PerformAlphaBlending(fg[3 + i] + x0, fg[3 + alpha] + x0, bg[3 + i] + x0,
                           bg[3 + alpha] + x0, tmp.Row(3 + i), xsize,
                           is_premultiplied, ec_blending[i].clamp);
    } else if (ec_blending[i].mode == PatchBlendMode::kAlphaWeightedAddAbove) {
      size_t alpha = ec_blending[i].alpha_channel;
      PerformAlphaWeightedAdd(bg[3 + i] + x0, fg[3 + i] + x0,
                              fg[3 + alpha] + x0, tmp.Row(3 + i), xsize,
                              ec_blending[i].clamp);
    } else if (ec_blending[i].mode == PatchBlendMode::kAlphaWeightedAddBelow) {
      size_t alpha = ec_blending[i].alpha_channel;
      PerformAlphaWeightedAdd(fg[3 + i] + x0, bg[3 + i] + x0,
                              bg[3 + alpha] + x0, tmp.Row(3 + i), xsize,
                              ec_blending[i].clamp);
    } else if (ec_blending[i].mode == PatchBlendMode::kMul) {
      PerformMulBlending(bg[3 + i] + x0, fg[3 + i] + x0, tmp.Row(3 + i), xsize,
                         ec_blending[i].clamp);
    } else if (ec_blending[i].mode == PatchBlendMode::kReplace) {
      memcpy(tmp.Row(3 + i), fg[3 + i] + x0, xsize * sizeof(**fg));
    } else if (ec_blending[i].mode == PatchBlendMode::kNone) {
      if (xsize) memcpy(tmp.Row(3 + i), bg[3 + i] + x0, xsize * sizeof(**fg));
    } else {
      JXL_UNREACHABLE("new PatchBlendMode?");
    }
  }
  size_t alpha = color_blending.alpha_channel;

  if (color_blending.mode == PatchBlendMode::kAdd ||
      (color_blending.mode == PatchBlendMode::kAlphaWeightedAddAbove &&
       !has_alpha) ||
      (color_blending.mode == PatchBlendMode::kAlphaWeightedAddBelow &&
       !has_alpha)) {
    for (int p = 0; p < 3; p++) {
      float* out = tmp.Row(p);
      for (size_t x = 0; x < xsize; x++) {
        out[x] = bg[p][x + x0] + fg[p][x + x0];
      }
    }
  } else if (color_blending.mode == PatchBlendMode::kBlendAbove
             // blend without alpha is just replace
             && has_alpha) {
    bool is_premultiplied = extra_channel_info[alpha].alpha_associated;
    PerformAlphaBlending(
        {bg[0] + x0, bg[1] + x0, bg[2] + x0, bg[3 + alpha] + x0},
        {fg[0] + x0, fg[1] + x0, fg[2] + x0, fg[3 + alpha] + x0},
        {tmp.Row(0), tmp.Row(1), tmp.Row(2), tmp.Row(3 + alpha)}, xsize,
        is_premultiplied, color_blending.clamp);
  } else if (color_blending.mode == PatchBlendMode::kBlendBelow
             // blend without alpha is just replace
             && has_alpha) {
    bool is_premultiplied = extra_channel_info[alpha].alpha_associated;
    PerformAlphaBlending(
        {fg[0] + x0, fg[1] + x0, fg[2] + x0, fg[3 + alpha] + x0},
        {bg[0] + x0, bg[1] + x0, bg[2] + x0, bg[3 + alpha] + x0},
        {tmp.Row(0), tmp.Row(1), tmp.Row(2), tmp.Row(3 + alpha)}, xsize,
        is_premultiplied, color_blending.clamp);
  } else if (color_blending.mode == PatchBlendMode::kAlphaWeightedAddAbove) {
    JXL_DASSERT(has_alpha);
    for (size_t c = 0; c < 3; c++) {
      PerformAlphaWeightedAdd(bg[c] + x0, fg[c] + x0, fg[3 + alpha] + x0,
                              tmp.Row(c), xsize, color_blending.clamp);
    }
  } else if (color_blending.mode == PatchBlendMode::kAlphaWeightedAddBelow) {
    JXL_DASSERT(has_alpha);
    for (size_t c = 0; c < 3; c++) {
      PerformAlphaWeightedAdd(fg[c] + x0, bg[c] + x0, bg[3 + alpha] + x0,
                              tmp.Row(c), xsize, color_blending.clamp);
    }
  } else if (color_blending.mode == PatchBlendMode::kMul) {
    for (int p = 0; p < 3; p++) {
      PerformMulBlending(bg[p] + x0, fg[p] + x0, tmp.Row(p), xsize,
                         color_blending.clamp);
    }
  } else if (color_blending.mode == PatchBlendMode::kReplace ||
             color_blending.mode == PatchBlendMode::kBlendAbove ||
             color_blending.mode == PatchBlendMode::kBlendBelow) {  // kReplace
    for (size_t p = 0; p < 3; p++) {
      memcpy(tmp.Row(p), fg[p] + x0, xsize * sizeof(**fg));
    }
  } else if (color_blending.mode == PatchBlendMode::kNone) {
    for (size_t p = 0; p < 3; p++) {
      memcpy(tmp.Row(p), bg[p] + x0, xsize * sizeof(**fg));
    }
  } else {
    JXL_UNREACHABLE("new PatchBlendMode?");
  }
  for (size_t i = 0; i < 3 + num_ec; i++) {
    if (xsize != 0) memcpy(out[i] + x0, tmp.Row(i), xsize * sizeof(**out));
  }
}

}  // namespace jxl
