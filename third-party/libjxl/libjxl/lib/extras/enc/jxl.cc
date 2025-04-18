// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/enc/jxl.h"

#include <jxl/encode.h>
#include <jxl/encode_cxx.h>

#include "lib/jxl/exif.h"

namespace jxl {
namespace extras {

JxlEncoderStatus SetOption(const JXLOption& opt,
                           JxlEncoderFrameSettings* settings) {
  return opt.is_float
             ? JxlEncoderFrameSettingsSetFloatOption(settings, opt.id, opt.fval)
             : JxlEncoderFrameSettingsSetOption(settings, opt.id, opt.ival);
}

bool SetFrameOptions(const std::vector<JXLOption>& options, size_t frame_index,
                     size_t* option_idx, JxlEncoderFrameSettings* settings) {
  while (*option_idx < options.size()) {
    const auto& opt = options[*option_idx];
    if (opt.frame_index > frame_index) {
      break;
    }
    if (JXL_ENC_SUCCESS != SetOption(opt, settings)) {
      fprintf(stderr, "Setting option id %d failed.\n", opt.id);
      return false;
    }
    (*option_idx)++;
  }
  return true;
}

bool EncodeImageJXL(const JXLCompressParams& params, const PackedPixelFile& ppf,
                    const std::vector<uint8_t>* jpeg_bytes,
                    std::vector<uint8_t>* compressed) {
  auto encoder = JxlEncoderMake(/*memory_manager=*/nullptr);
  JxlEncoder* enc = encoder.get();

  if (params.allow_expert_options) {
    JxlEncoderAllowExpertOptions(enc);
  }

  if (params.runner_opaque != nullptr &&
      JXL_ENC_SUCCESS != JxlEncoderSetParallelRunner(enc, params.runner,
                                                     params.runner_opaque)) {
    fprintf(stderr, "JxlEncoderSetParallelRunner failed\n");
    return false;
  }

  auto settings = JxlEncoderFrameSettingsCreate(enc, nullptr);
  size_t option_idx = 0;
  if (!SetFrameOptions(params.options, 0, &option_idx, settings)) {
    return false;
  }
  if (JXL_ENC_SUCCESS !=
      JxlEncoderSetFrameDistance(settings, params.distance)) {
    fprintf(stderr, "Setting frame distance failed.\n");
    return false;
  }
  if (params.debug_image) {
    JxlEncoderSetDebugImageCallback(settings, params.debug_image,
                                    params.debug_image_opaque);
  }
  if (params.stats) {
    JxlEncoderCollectStats(settings, params.stats);
  }

  bool use_boxes = !ppf.metadata.exif.empty() || !ppf.metadata.xmp.empty() ||
                   !ppf.metadata.jumbf.empty() || !ppf.metadata.iptc.empty();
  bool use_container = params.use_container || use_boxes ||
                       (jpeg_bytes && params.jpeg_store_metadata);

  if (JXL_ENC_SUCCESS !=
      JxlEncoderUseContainer(enc, static_cast<int>(use_container))) {
    fprintf(stderr, "JxlEncoderUseContainer failed.\n");
    return false;
  }

  if (jpeg_bytes) {
    if (params.jpeg_store_metadata &&
        JXL_ENC_SUCCESS != JxlEncoderStoreJPEGMetadata(enc, JXL_TRUE)) {
      fprintf(stderr, "Storing JPEG metadata failed.\n");
      return false;
    }
    if (!params.jpeg_store_metadata && params.jpeg_strip_exif) {
      JxlEncoderFrameSettingsSetOption(settings,
                                       JXL_ENC_FRAME_SETTING_JPEG_KEEP_EXIF, 0);
    }
    if (!params.jpeg_store_metadata && params.jpeg_strip_xmp) {
      JxlEncoderFrameSettingsSetOption(settings,
                                       JXL_ENC_FRAME_SETTING_JPEG_KEEP_XMP, 0);
    }
    if (params.jpeg_strip_jumbf) {
      JxlEncoderFrameSettingsSetOption(
          settings, JXL_ENC_FRAME_SETTING_JPEG_KEEP_JUMBF, 0);
    }
    if (JXL_ENC_SUCCESS != JxlEncoderAddJPEGFrame(settings, jpeg_bytes->data(),
                                                  jpeg_bytes->size())) {
      JxlEncoderError error = JxlEncoderGetError(enc);
      if (error == JXL_ENC_ERR_BAD_INPUT) {
        fprintf(stderr,
                "Error while decoding the JPEG image. It may be corrupt (e.g. "
                "truncated) or of an unsupported type (e.g. CMYK).\n");
      } else if (error == JXL_ENC_ERR_JBRD) {
        fprintf(stderr,
                "JPEG bitstream reconstruction data could not be created. "
                "Possibly there is too much tail data.\n"
                "Try using --jpeg_store_metadata 0, to losslessly "
                "recompress the JPEG image data without bitstream "
                "reconstruction data.\n");
      } else {
        fprintf(stderr, "JxlEncoderAddJPEGFrame() failed.\n");
      }
      return false;
    }
  } else {
    size_t num_alpha_channels = 0;  // Adjusted below.
    JxlBasicInfo basic_info = ppf.info;
    basic_info.xsize *= params.already_downsampled;
    basic_info.ysize *= params.already_downsampled;
    if (basic_info.alpha_bits > 0) num_alpha_channels = 1;
    if (params.intensity_target > 0) {
      basic_info.intensity_target = params.intensity_target;
    }
    basic_info.num_extra_channels =
        std::max<uint32_t>(num_alpha_channels, ppf.info.num_extra_channels);
    basic_info.num_color_channels = ppf.info.num_color_channels;
    const bool lossless = params.distance == 0;
    basic_info.uses_original_profile = lossless;
    if (params.override_bitdepth != 0) {
      basic_info.bits_per_sample = params.override_bitdepth;
      basic_info.exponent_bits_per_sample =
          params.override_bitdepth == 32 ? 8 : 0;
    }
    if (JXL_ENC_SUCCESS !=
        JxlEncoderSetCodestreamLevel(enc, params.codestream_level)) {
      fprintf(stderr, "Setting --codestream_level failed.\n");
      return false;
    }
    if (JXL_ENC_SUCCESS != JxlEncoderSetBasicInfo(enc, &basic_info)) {
      fprintf(stderr, "JxlEncoderSetBasicInfo() failed.\n");
      return false;
    }
    if (JXL_ENC_SUCCESS !=
        JxlEncoderSetUpsamplingMode(enc, params.already_downsampled,
                                    params.upsampling_mode)) {
      fprintf(stderr, "JxlEncoderSetUpsamplingMode() failed.\n");
      return false;
    }
    if (JXL_ENC_SUCCESS !=
        JxlEncoderSetFrameBitDepth(settings, &params.input_bitdepth)) {
      fprintf(stderr, "JxlEncoderSetFrameBitDepth() failed.\n");
      return false;
    }
    if (num_alpha_channels != 0 &&
        JXL_ENC_SUCCESS != JxlEncoderSetExtraChannelDistance(
                               settings, 0, params.alpha_distance)) {
      fprintf(stderr, "Setting alpha distance failed.\n");
      return false;
    }
    if (lossless &&
        JXL_ENC_SUCCESS != JxlEncoderSetFrameLossless(settings, JXL_TRUE)) {
      fprintf(stderr, "JxlEncoderSetFrameLossless() failed.\n");
      return false;
    }
    if (!ppf.icc.empty()) {
      if (JXL_ENC_SUCCESS !=
          JxlEncoderSetICCProfile(enc, ppf.icc.data(), ppf.icc.size())) {
        fprintf(stderr, "JxlEncoderSetICCProfile() failed.\n");
        return false;
      }
    } else {
      if (JXL_ENC_SUCCESS !=
          JxlEncoderSetColorEncoding(enc, &ppf.color_encoding)) {
        fprintf(stderr, "JxlEncoderSetColorEncoding() failed.\n");
        return false;
      }
    }

    if (use_boxes) {
      if (JXL_ENC_SUCCESS != JxlEncoderUseBoxes(enc)) {
        fprintf(stderr, "JxlEncoderUseBoxes() failed.\n");
        return false;
      }
      // Prepend 4 zero bytes to exif for tiff header offset
      std::vector<uint8_t> exif_with_offset;
      bool bigendian;
      if (IsExif(ppf.metadata.exif, &bigendian)) {
        exif_with_offset.resize(ppf.metadata.exif.size() + 4);
        memcpy(exif_with_offset.data() + 4, ppf.metadata.exif.data(),
               ppf.metadata.exif.size());
      }
      const struct BoxInfo {
        const char* type;
        const std::vector<uint8_t>& bytes;
      } boxes[] = {
          {"Exif", exif_with_offset},
          {"xml ", ppf.metadata.xmp},
          {"jumb", ppf.metadata.jumbf},
          {"xml ", ppf.metadata.iptc},
      };
      for (size_t i = 0; i < sizeof boxes / sizeof *boxes; ++i) {
        const BoxInfo& box = boxes[i];
        if (!box.bytes.empty() &&
            JXL_ENC_SUCCESS != JxlEncoderAddBox(enc, box.type, box.bytes.data(),
                                                box.bytes.size(),
                                                params.compress_boxes)) {
          fprintf(stderr, "JxlEncoderAddBox() failed (%s).\n", box.type);
          return false;
        }
      }
      JxlEncoderCloseBoxes(enc);
    }

    for (size_t num_frame = 0; num_frame < ppf.frames.size(); ++num_frame) {
      const jxl::extras::PackedFrame& pframe = ppf.frames[num_frame];
      const jxl::extras::PackedImage& pimage = pframe.color;
      JxlPixelFormat ppixelformat = pimage.format;
      if (JXL_ENC_SUCCESS !=
          JxlEncoderSetFrameHeader(settings, &pframe.frame_info)) {
        fprintf(stderr, "JxlEncoderSetFrameHeader() failed.\n");
        return false;
      }
      if (!SetFrameOptions(params.options, num_frame, &option_idx, settings)) {
        return false;
      }
      if (num_alpha_channels > 0) {
        JxlExtraChannelInfo extra_channel_info;
        JxlEncoderInitExtraChannelInfo(JXL_CHANNEL_ALPHA, &extra_channel_info);
        extra_channel_info.bits_per_sample = ppf.info.alpha_bits;
        extra_channel_info.exponent_bits_per_sample =
            ppf.info.alpha_exponent_bits;
        if (params.premultiply != -1) {
          if (params.premultiply != 0 && params.premultiply != 1) {
            fprintf(stderr, "premultiply must be one of: -1, 0, 1.\n");
            return false;
          }
          extra_channel_info.alpha_premultiplied = params.premultiply;
        }
        if (JXL_ENC_SUCCESS !=
            JxlEncoderSetExtraChannelInfo(enc, 0, &extra_channel_info)) {
          fprintf(stderr, "JxlEncoderSetExtraChannelInfo() failed.\n");
          return false;
        }
        // We take the extra channel blend info frame_info, but don't do
        // clamping.
        JxlBlendInfo extra_channel_blend_info =
            pframe.frame_info.layer_info.blend_info;
        extra_channel_blend_info.clamp = JXL_FALSE;
        JxlEncoderSetExtraChannelBlendInfo(settings, 0,
                                           &extra_channel_blend_info);
      }
      size_t num_interleaved_alpha =
          (ppixelformat.num_channels - ppf.info.num_color_channels);
      // Add extra channel info for the rest of the extra channels.
      for (size_t i = 0; i < ppf.info.num_extra_channels; ++i) {
        if (i < ppf.extra_channels_info.size()) {
          const auto& ec_info = ppf.extra_channels_info[i].ec_info;
          if (JXL_ENC_SUCCESS !=
              JxlEncoderSetExtraChannelInfo(enc, num_interleaved_alpha + i,
                                            &ec_info)) {
            fprintf(stderr, "JxlEncoderSetExtraChannelInfo() failed.\n");
            return false;
          }
        }
      }
      if (JXL_ENC_SUCCESS != JxlEncoderAddImageFrame(settings, &ppixelformat,
                                                     pimage.pixels(),
                                                     pimage.pixels_size)) {
        fprintf(stderr, "JxlEncoderAddImageFrame() failed.\n");
        return false;
      }
      // Only set extra channel buffer if it is provided non-interleaved.
      for (size_t i = 0; i < pframe.extra_channels.size(); ++i) {
        if (JXL_ENC_SUCCESS !=
            JxlEncoderSetExtraChannelBuffer(settings, &ppixelformat,
                                            pframe.extra_channels[i].pixels(),
                                            pframe.extra_channels[i].stride *
                                                pframe.extra_channels[i].ysize,
                                            num_interleaved_alpha + i)) {
          fprintf(stderr, "JxlEncoderSetExtraChannelBuffer() failed.\n");
          return false;
        }
      }
    }
  }
  JxlEncoderCloseInput(enc);
  // Reading compressed output
  compressed->clear();
  compressed->resize(4096);
  uint8_t* next_out = compressed->data();
  size_t avail_out = compressed->size() - (next_out - compressed->data());
  JxlEncoderStatus result = JXL_ENC_NEED_MORE_OUTPUT;
  while (result == JXL_ENC_NEED_MORE_OUTPUT) {
    result = JxlEncoderProcessOutput(enc, &next_out, &avail_out);
    if (result == JXL_ENC_NEED_MORE_OUTPUT) {
      size_t offset = next_out - compressed->data();
      compressed->resize(compressed->size() * 2);
      next_out = compressed->data() + offset;
      avail_out = compressed->size() - offset;
    }
  }
  compressed->resize(next_out - compressed->data());
  if (result != JXL_ENC_SUCCESS) {
    fprintf(stderr, "JxlEncoderProcessOutput failed.\n");
    return false;
  }
  return true;
}

}  // namespace extras
}  // namespace jxl
