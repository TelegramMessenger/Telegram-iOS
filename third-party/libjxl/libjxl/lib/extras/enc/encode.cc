// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/enc/encode.h"

#include <locale>

#include "lib/extras/enc/apng.h"
#include "lib/extras/enc/exr.h"
#include "lib/extras/enc/jpg.h"
#include "lib/extras/enc/npy.h"
#include "lib/extras/enc/pgx.h"
#include "lib/extras/enc/pnm.h"
#include "lib/jxl/base/printf_macros.h"

namespace jxl {
namespace extras {

Status Encoder::VerifyBasicInfo(const JxlBasicInfo& info) {
  if (info.xsize == 0 || info.ysize == 0) {
    return JXL_FAILURE("Empty image");
  }
  if (info.num_color_channels != 1 && info.num_color_channels != 3) {
    return JXL_FAILURE("Invalid number of color channels");
  }
  if (info.alpha_bits > 0 && info.alpha_bits != info.bits_per_sample) {
    return JXL_FAILURE("Alpha bit depth does not match image bit depth");
  }
  if (info.orientation != JXL_ORIENT_IDENTITY) {
    return JXL_FAILURE("Orientation must be identity");
  }
  return true;
}

Status Encoder::VerifyFormat(const JxlPixelFormat& format) const {
  for (auto f : AcceptedFormats()) {
    if (f.num_channels != format.num_channels) continue;
    if (f.data_type != format.data_type) continue;
    if (f.data_type == JXL_TYPE_UINT8 || f.endianness == format.endianness) {
      return true;
    }
  }
  return JXL_FAILURE("Format is not in the list of accepted formats.");
}

Status Encoder::VerifyBitDepth(JxlDataType data_type, uint32_t bits_per_sample,
                               uint32_t exponent_bits) {
  if ((data_type == JXL_TYPE_UINT8 &&
       (bits_per_sample == 0 || bits_per_sample > 8 || exponent_bits != 0)) ||
      (data_type == JXL_TYPE_UINT16 &&
       (bits_per_sample <= 8 || bits_per_sample > 16 || exponent_bits != 0)) ||
      (data_type == JXL_TYPE_FLOAT16 &&
       (bits_per_sample > 16 || exponent_bits > 5))) {
    return JXL_FAILURE(
        "Incompatible data_type %d and bit depth %u with exponent bits %u",
        (int)data_type, bits_per_sample, exponent_bits);
  }
  return true;
}

Status Encoder::VerifyImageSize(const PackedImage& image,
                                const JxlBasicInfo& info) {
  if (image.pixels() == nullptr) {
    return JXL_FAILURE("Invalid image.");
  }
  if (image.stride != image.xsize * image.pixel_stride()) {
    return JXL_FAILURE("Invalid image stride.");
  }
  if (image.pixels_size != image.ysize * image.stride) {
    return JXL_FAILURE("Invalid image size.");
  }
  size_t info_num_channels =
      (info.num_color_channels + (info.alpha_bits > 0 ? 1 : 0));
  if (image.xsize != info.xsize || image.ysize != info.ysize ||
      image.format.num_channels != info_num_channels) {
    return JXL_FAILURE("Frame size does not match image size");
  }
  return true;
}

Status Encoder::VerifyPackedImage(const PackedImage& image,
                                  const JxlBasicInfo& info) const {
  JXL_RETURN_IF_ERROR(VerifyImageSize(image, info));
  JXL_RETURN_IF_ERROR(VerifyFormat(image.format));
  JXL_RETURN_IF_ERROR(VerifyBitDepth(image.format.data_type,
                                     info.bits_per_sample,
                                     info.exponent_bits_per_sample));
  return true;
}

Status SelectFormat(const std::vector<JxlPixelFormat>& accepted_formats,
                    const JxlBasicInfo& basic_info, JxlPixelFormat* format) {
  const size_t original_bit_depth = basic_info.bits_per_sample;
  size_t current_bit_depth = 0;
  size_t num_alpha_channels = (basic_info.alpha_bits != 0 ? 1 : 0);
  size_t num_channels = basic_info.num_color_channels + num_alpha_channels;
  for (;;) {
    for (const JxlPixelFormat& candidate : accepted_formats) {
      if (candidate.num_channels != num_channels) continue;
      const size_t candidate_bit_depth =
          PackedImage::BitsPerChannel(candidate.data_type);
      if (
          // Candidate bit depth is less than what we have and still enough
          (original_bit_depth <= candidate_bit_depth &&
           candidate_bit_depth < current_bit_depth) ||
          // Or larger than the too-small bit depth we currently have
          (current_bit_depth < candidate_bit_depth &&
           current_bit_depth < original_bit_depth)) {
        *format = candidate;
        current_bit_depth = candidate_bit_depth;
      }
    }
    if (current_bit_depth == 0) {
      if (num_channels > basic_info.num_color_channels) {
        // Try dropping the alpha channel.
        --num_channels;
        continue;
      }
      return JXL_FAILURE("no appropriate format found");
    }
    break;
  }
  if (current_bit_depth < original_bit_depth) {
    JXL_WARNING("encoding %" PRIuS "-bit original to %" PRIuS " bits",
                original_bit_depth, current_bit_depth);
  }
  return true;
}

template <int metadata>
class MetadataEncoder : public Encoder {
 public:
  std::vector<JxlPixelFormat> AcceptedFormats() const override {
    std::vector<JxlPixelFormat> formats;
    // empty, i.e. no need for actual pixel data
    return formats;
  }

  Status Encode(const PackedPixelFile& ppf, EncodedImage* encoded,
                ThreadPool* pool) const override {
    JXL_RETURN_IF_ERROR(VerifyBasicInfo(ppf.info));
    encoded->icc.clear();
    encoded->bitstreams.resize(1);
    if (metadata == 0) encoded->bitstreams.front() = ppf.metadata.exif;
    if (metadata == 1) encoded->bitstreams.front() = ppf.metadata.xmp;
    if (metadata == 2) encoded->bitstreams.front() = ppf.metadata.jumbf;
    return true;
  }
};

std::unique_ptr<Encoder> Encoder::FromExtension(std::string extension) {
  std::transform(
      extension.begin(), extension.end(), extension.begin(),
      [](char c) { return std::tolower(c, std::locale::classic()); });
  if (extension == ".png" || extension == ".apng") return GetAPNGEncoder();
  if (extension == ".jpg") return GetJPEGEncoder();
  if (extension == ".jpeg") return GetJPEGEncoder();
  if (extension == ".npy") return GetNumPyEncoder();
  if (extension == ".pgx") return GetPGXEncoder();
  if (extension == ".pam") return GetPAMEncoder();
  if (extension == ".pgm") return GetPGMEncoder();
  if (extension == ".ppm") return GetPPMEncoder();
  if (extension == ".pfm") return GetPFMEncoder();
  if (extension == ".exr") return GetEXREncoder();
  if (extension == ".exif") return jxl::make_unique<MetadataEncoder<0>>();
  if (extension == ".xmp") return jxl::make_unique<MetadataEncoder<1>>();
  if (extension == ".xml") return jxl::make_unique<MetadataEncoder<1>>();
  if (extension == ".jumbf") return jxl::make_unique<MetadataEncoder<2>>();
  if (extension == ".jumb") return jxl::make_unique<MetadataEncoder<2>>();

  return nullptr;
}

}  // namespace extras
}  // namespace jxl
