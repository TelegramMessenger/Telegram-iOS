// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_cache.h"

#include <stddef.h>
#include <stdint.h>

#include <type_traits>

#include "lib/jxl/ac_strategy.h"
#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/common.h"
#include "lib/jxl/compressed_dc.h"
#include "lib/jxl/dct_scales.h"
#include "lib/jxl/dct_util.h"
#include "lib/jxl/dec_frame.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/enc_frame.h"
#include "lib/jxl/enc_group.h"
#include "lib/jxl/enc_modular.h"
#include "lib/jxl/enc_quant_weights.h"
#include "lib/jxl/frame_header.h"
#include "lib/jxl/image.h"
#include "lib/jxl/image_bundle.h"
#include "lib/jxl/image_ops.h"
#include "lib/jxl/passes_state.h"
#include "lib/jxl/quantizer.h"

namespace jxl {

Status InitializePassesEncoder(const Image3F& opsin, const JxlCmsInterface& cms,
                               ThreadPool* pool, PassesEncoderState* enc_state,
                               ModularFrameEncoder* modular_frame_encoder,
                               AuxOut* aux_out) {
  PassesSharedState& JXL_RESTRICT shared = enc_state->shared;

  enc_state->histogram_idx.resize(shared.frame_dim.num_groups);

  enc_state->x_qm_multiplier =
      std::pow(1.25f, shared.frame_header.x_qm_scale - 2.0f);
  enc_state->b_qm_multiplier =
      std::pow(1.25f, shared.frame_header.b_qm_scale - 2.0f);

  if (enc_state->coeffs.size() < shared.frame_header.passes.num_passes) {
    enc_state->coeffs.reserve(shared.frame_header.passes.num_passes);
    for (size_t i = enc_state->coeffs.size();
         i < shared.frame_header.passes.num_passes; i++) {
      // Allocate enough coefficients for each group on every row.
      enc_state->coeffs.emplace_back(make_unique<ACImageT<int32_t>>(
          kGroupDim * kGroupDim, shared.frame_dim.num_groups));
    }
  }
  while (enc_state->coeffs.size() > shared.frame_header.passes.num_passes) {
    enc_state->coeffs.pop_back();
  }

  float scale =
      shared.quantizer.ScaleGlobalScale(enc_state->cparams.quant_ac_rescale);
  DequantMatricesScaleDC(&shared.matrices, scale);
  shared.quantizer.RecomputeFromGlobalScale();

  Image3F dc(shared.frame_dim.xsize_blocks, shared.frame_dim.ysize_blocks);
  JXL_RETURN_IF_ERROR(RunOnPool(
      pool, 0, shared.frame_dim.num_groups, ThreadPool::NoInit,
      [&](size_t group_idx, size_t _) {
        ComputeCoefficients(group_idx, enc_state, opsin, &dc);
      },
      "Compute coeffs"));

  if (shared.frame_header.flags & FrameHeader::kUseDcFrame) {
    CompressParams cparams = enc_state->cparams;
    cparams.dots = Override::kOff;
    cparams.noise = Override::kOff;
    cparams.patches = Override::kOff;
    cparams.gaborish = Override::kOff;
    cparams.epf = 0;
    cparams.resampling = 1;
    cparams.ec_resampling = 1;
    // The DC frame will have alpha=0. Don't erase its contents.
    cparams.keep_invisible = Override::kOn;
    JXL_ASSERT(cparams.progressive_dc > 0);
    cparams.progressive_dc--;
    // Use kVarDCT in max_error_mode for intermediate progressive DC,
    // and kModular for the smallest DC (first in the bitstream)
    if (cparams.progressive_dc == 0) {
      cparams.modular_mode = true;
      cparams.speed_tier =
          SpeedTier(std::max(static_cast<int>(SpeedTier::kTortoise),
                             static_cast<int>(cparams.speed_tier) - 1));
      cparams.butteraugli_distance =
          std::max(kMinButteraugliDistance,
                   enc_state->cparams.butteraugli_distance * 0.02f);
    } else {
      cparams.max_error_mode = true;
      for (size_t c = 0; c < 3; c++) {
        cparams.max_error[c] = shared.quantizer.MulDC()[c];
      }
      // Guess a distance that produces good initial results.
      cparams.butteraugli_distance =
          std::max(kMinButteraugliDistance,
                   enc_state->cparams.butteraugli_distance * 0.1f);
    }
    ImageBundle ib(&shared.metadata->m);
    // This is a lie - dc is in XYB
    // (but EncodeFrame will skip RGB->XYB conversion anyway)
    ib.SetFromImage(
        std::move(dc),
        ColorEncoding::LinearSRGB(shared.metadata->m.color_encoding.IsGray()));
    if (!ib.metadata()->extra_channel_info.empty()) {
      // Add dummy extra channels to the patch image: dc_level frames do not yet
      // support extra channels, but the codec expects that the amount of extra
      // channels in frames matches that in the metadata of the codestream.
      std::vector<ImageF> extra_channels;
      extra_channels.reserve(ib.metadata()->extra_channel_info.size());
      for (size_t i = 0; i < ib.metadata()->extra_channel_info.size(); i++) {
        extra_channels.emplace_back(ib.xsize(), ib.ysize());
        // Must initialize the image with data to not affect blending with
        // uninitialized memory.
        // TODO(lode): dc_level must copy and use the real extra channels
        // instead.
        ZeroFillImage(&extra_channels.back());
      }
      ib.SetExtraChannels(std::move(extra_channels));
    }
    std::unique_ptr<PassesEncoderState> state =
        jxl::make_unique<PassesEncoderState>();

    auto special_frame = std::unique_ptr<BitWriter>(new BitWriter());
    FrameInfo dc_frame_info;
    dc_frame_info.frame_type = FrameType::kDCFrame;
    dc_frame_info.dc_level = shared.frame_header.dc_level + 1;
    dc_frame_info.ib_needs_color_transform = false;
    dc_frame_info.save_before_color_transform = true;  // Implicitly true
    AuxOut dc_aux_out;
    JXL_CHECK(EncodeFrame(cparams, dc_frame_info, shared.metadata, ib,
                          state.get(), cms, pool, special_frame.get(),
                          aux_out ? &dc_aux_out : nullptr));
    if (aux_out) {
      for (const auto& l : dc_aux_out.layers) {
        aux_out->layers[kLayerDC].Assimilate(l);
      }
    }
    const Span<const uint8_t> encoded = special_frame->GetSpan();
    enc_state->special_frames.emplace_back(std::move(special_frame));

    ImageBundle decoded(&shared.metadata->m);
    std::unique_ptr<PassesDecoderState> dec_state =
        jxl::make_unique<PassesDecoderState>();
    JXL_CHECK(
        dec_state->output_encoding_info.SetFromMetadata(*shared.metadata));
    const uint8_t* frame_start = encoded.data();
    size_t encoded_size = encoded.size();
    for (int i = 0; i <= cparams.progressive_dc; ++i) {
      JXL_CHECK(DecodeFrame(dec_state.get(), pool, frame_start, encoded_size,
                            &decoded, *shared.metadata));
      frame_start += decoded.decoded_bytes();
      encoded_size -= decoded.decoded_bytes();
    }
    // TODO(lode): shared.frame_header.dc_level should be equal to
    // dec_state.shared->frame_header.dc_level - 1 here, since above we set
    // dc_frame_info.dc_level = shared.frame_header.dc_level + 1, and
    // dc_frame_info.dc_level is used by EncodeFrame. However, if EncodeFrame
    // outputs multiple frames, this assumption could be wrong.
    const Image3F& dc_frame =
        dec_state->shared->dc_frames[shared.frame_header.dc_level];
    shared.dc_storage = Image3F(dc_frame.xsize(), dc_frame.ysize());
    CopyImageTo(dc_frame, &shared.dc_storage);
    ZeroFillImage(&shared.quant_dc);
    shared.dc = &shared.dc_storage;
    JXL_CHECK(encoded_size == 0);
  } else {
    auto compute_dc_coeffs = [&](int group_index, int /* thread */) {
      modular_frame_encoder->AddVarDCTDC(
          dc, group_index, enc_state->cparams.speed_tier < SpeedTier::kFalcon,
          enc_state, /*jpeg_transcode=*/false);
    };
    JXL_RETURN_IF_ERROR(RunOnPool(pool, 0, shared.frame_dim.num_dc_groups,
                                  ThreadPool::NoInit, compute_dc_coeffs,
                                  "Compute DC coeffs"));
    // TODO(veluca): this is only useful in tests and if inspection is enabled.
    if (!(shared.frame_header.flags & FrameHeader::kSkipAdaptiveDCSmoothing)) {
      AdaptiveDCSmoothing(shared.quantizer.MulDC(), &shared.dc_storage, pool);
    }
  }
  auto compute_ac_meta = [&](int group_index, int /* thread */) {
    modular_frame_encoder->AddACMetadata(group_index, /*jpeg_transcode=*/false,
                                         enc_state);
  };
  JXL_RETURN_IF_ERROR(RunOnPool(pool, 0, shared.frame_dim.num_dc_groups,
                                ThreadPool::NoInit, compute_ac_meta,
                                "Compute AC Metadata"));

  return true;
}

void EncCache::InitOnce() {
  if (num_nzeroes.xsize() == 0) {
    num_nzeroes = Image3I(kGroupDimInBlocks, kGroupDimInBlocks);
  }
}

}  // namespace jxl
