// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/dec_cache.h"

#include "lib/jxl/blending.h"
#include "lib/jxl/render_pipeline/stage_blending.h"
#include "lib/jxl/render_pipeline/stage_chroma_upsampling.h"
#include "lib/jxl/render_pipeline/stage_epf.h"
#include "lib/jxl/render_pipeline/stage_from_linear.h"
#include "lib/jxl/render_pipeline/stage_gaborish.h"
#include "lib/jxl/render_pipeline/stage_noise.h"
#include "lib/jxl/render_pipeline/stage_patches.h"
#include "lib/jxl/render_pipeline/stage_splines.h"
#include "lib/jxl/render_pipeline/stage_spot.h"
#include "lib/jxl/render_pipeline/stage_to_linear.h"
#include "lib/jxl/render_pipeline/stage_tone_mapping.h"
#include "lib/jxl/render_pipeline/stage_upsampling.h"
#include "lib/jxl/render_pipeline/stage_write.h"
#include "lib/jxl/render_pipeline/stage_xyb.h"
#include "lib/jxl/render_pipeline/stage_ycbcr.h"

namespace jxl {

Status PassesDecoderState::PreparePipeline(ImageBundle* decoded,
                                           PipelineOptions options) {
  const FrameHeader& frame_header = shared->frame_header;
  size_t num_c = 3 + frame_header.nonserialized_metadata->m.num_extra_channels;
  if ((frame_header.flags & FrameHeader::kNoise) != 0) {
    num_c += 3;
  }

  if (frame_header.CanBeReferenced()) {
    // Necessary so that SetInputSizes() can allocate output buffers as needed.
    frame_storage_for_referencing = ImageBundle(decoded->metadata());
  }

  RenderPipeline::Builder builder(num_c);

  if (options.use_slow_render_pipeline) {
    builder.UseSimpleImplementation();
  }

  if (!frame_header.chroma_subsampling.Is444()) {
    for (size_t c = 0; c < 3; c++) {
      if (frame_header.chroma_subsampling.HShift(c) != 0) {
        builder.AddStage(GetChromaUpsamplingStage(c, /*horizontal=*/true));
      }
      if (frame_header.chroma_subsampling.VShift(c) != 0) {
        builder.AddStage(GetChromaUpsamplingStage(c, /*horizontal=*/false));
      }
    }
  }

  if (frame_header.loop_filter.gab) {
    builder.AddStage(GetGaborishStage(frame_header.loop_filter));
  }

  {
    const LoopFilter& lf = frame_header.loop_filter;
    if (lf.epf_iters >= 3) {
      builder.AddStage(GetEPFStage(lf, sigma, 0));
    }
    if (lf.epf_iters >= 1) {
      builder.AddStage(GetEPFStage(lf, sigma, 1));
    }
    if (lf.epf_iters >= 2) {
      builder.AddStage(GetEPFStage(lf, sigma, 2));
    }
  }

  bool late_ec_upsample = frame_header.upsampling != 1;
  for (auto ecups : frame_header.extra_channel_upsampling) {
    if (ecups != frame_header.upsampling) {
      // If patches are applied, either frame_header.upsampling == 1 or
      // late_ec_upsample is true.
      late_ec_upsample = false;
    }
  }

  if (!late_ec_upsample) {
    for (size_t ec = 0; ec < frame_header.extra_channel_upsampling.size();
         ec++) {
      if (frame_header.extra_channel_upsampling[ec] != 1) {
        builder.AddStage(GetUpsamplingStage(
            frame_header.nonserialized_metadata->transform_data, 3 + ec,
            CeilLog2Nonzero(frame_header.extra_channel_upsampling[ec])));
      }
    }
  }

  if ((frame_header.flags & FrameHeader::kPatches) != 0) {
    builder.AddStage(
        GetPatchesStage(&shared->image_features.patches,
                        3 + shared->metadata->m.num_extra_channels));
  }
  if ((frame_header.flags & FrameHeader::kSplines) != 0) {
    builder.AddStage(GetSplineStage(&shared->image_features.splines));
  }

  if (frame_header.upsampling != 1) {
    size_t nb_channels =
        3 +
        (late_ec_upsample ? frame_header.extra_channel_upsampling.size() : 0);
    for (size_t c = 0; c < nb_channels; c++) {
      builder.AddStage(GetUpsamplingStage(
          frame_header.nonserialized_metadata->transform_data, c,
          CeilLog2Nonzero(frame_header.upsampling)));
    }
  }

  if ((frame_header.flags & FrameHeader::kNoise) != 0) {
    builder.AddStage(GetConvolveNoiseStage(num_c - 3));
    builder.AddStage(GetAddNoiseStage(shared->image_features.noise_params,
                                      shared->cmap, num_c - 3));
  }
  if (frame_header.dc_level != 0) {
    builder.AddStage(GetWriteToImage3FStage(
        &shared_storage.dc_frames[frame_header.dc_level - 1]));
  }

  if (frame_header.CanBeReferenced() &&
      frame_header.save_before_color_transform) {
    builder.AddStage(GetWriteToImageBundleStage(
        &frame_storage_for_referencing, output_encoding_info.color_encoding));
  }

  bool has_alpha = false;
  size_t alpha_c = 0;
  for (size_t i = 0; i < decoded->metadata()->extra_channel_info.size(); i++) {
    if (decoded->metadata()->extra_channel_info[i].type ==
        ExtraChannel::kAlpha) {
      has_alpha = true;
      alpha_c = 3 + i;
      break;
    }
  }

  if (fast_xyb_srgb8_conversion) {
#if !JXL_HIGH_PRECISION
    JXL_ASSERT(!NeedsBlending(this));
    JXL_ASSERT(!frame_header.CanBeReferenced() ||
               frame_header.save_before_color_transform);
    JXL_ASSERT(!options.render_spotcolors ||
               !decoded->metadata()->Find(ExtraChannel::kSpotColor));
    bool is_rgba = (main_output.format.num_channels == 4);
    uint8_t* rgb_output = reinterpret_cast<uint8_t*>(main_output.buffer);
    builder.AddStage(GetFastXYBTosRGB8Stage(rgb_output, main_output.stride,
                                            width, height, is_rgba, has_alpha,
                                            alpha_c));
#endif
  } else {
    bool linear = false;
    if (frame_header.color_transform == ColorTransform::kYCbCr) {
      builder.AddStage(GetYCbCrStage());
    } else if (frame_header.color_transform == ColorTransform::kXYB) {
      builder.AddStage(GetXYBStage(output_encoding_info));
      if (output_encoding_info.color_encoding.GetColorSpace() !=
          ColorSpace::kXYB) {
        linear = true;
      }
    }  // Nothing to do for kNone.

    if (options.coalescing && NeedsBlending(this)) {
      if (linear) {
        builder.AddStage(GetFromLinearStage(output_encoding_info));
        linear = false;
      }
      builder.AddStage(
          GetBlendingStage(this, output_encoding_info.color_encoding));
    }

    if (options.coalescing && frame_header.CanBeReferenced() &&
        !frame_header.save_before_color_transform) {
      if (linear) {
        builder.AddStage(GetFromLinearStage(output_encoding_info));
        linear = false;
      }
      builder.AddStage(GetWriteToImageBundleStage(
          &frame_storage_for_referencing, output_encoding_info.color_encoding));
    }

    if (options.render_spotcolors &&
        frame_header.nonserialized_metadata->m.Find(ExtraChannel::kSpotColor)) {
      for (size_t i = 0; i < decoded->metadata()->extra_channel_info.size();
           i++) {
        // Don't use Find() because there may be multiple spot color channels.
        const ExtraChannelInfo& eci =
            decoded->metadata()->extra_channel_info[i];
        if (eci.type == ExtraChannel::kSpotColor) {
          builder.AddStage(GetSpotColorStage(3 + i, eci.spot_color));
        }
      }
    }

    auto tone_mapping_stage = GetToneMappingStage(output_encoding_info);
    if (tone_mapping_stage) {
      if (!linear) {
        auto to_linear_stage = GetToLinearStage(output_encoding_info);
        if (!to_linear_stage) {
          return JXL_FAILURE(
              "attempting to perform tone mapping on colorspace not "
              "convertible to linear");
        }
        builder.AddStage(std::move(to_linear_stage));
        linear = true;
      }
      builder.AddStage(std::move(tone_mapping_stage));
    }

    if (linear) {
      builder.AddStage(GetFromLinearStage(output_encoding_info));
      linear = false;
    }

    if (main_output.callback.IsPresent() || main_output.buffer) {
      builder.AddStage(GetWriteToOutputStage(main_output, width, height,
                                             has_alpha, unpremul_alpha, alpha_c,
                                             undo_orientation, extra_output));
    } else {
      builder.AddStage(GetWriteToImageBundleStage(
          decoded, output_encoding_info.color_encoding));
    }
  }
  render_pipeline = std::move(builder).Finalize(shared->frame_dim);
  return render_pipeline->IsInitialized();
}

}  // namespace jxl
