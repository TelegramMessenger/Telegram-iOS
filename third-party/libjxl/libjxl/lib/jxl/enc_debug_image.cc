// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_debug_image.h"

#include <stddef.h>
#include <stdint.h>

#include "lib/jxl/base/status.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/dec_external_image.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_params.h"
#include "lib/jxl/image_ops.h"

namespace jxl {

namespace {
template <typename T>
void DumpImageT(const CompressParams& cparams, const char* label,
                const ColorEncoding& color_encoding, const Image3<T>& image) {
  if (!cparams.debug_image) return;
  Image3F float_image = ConvertToFloat(image);
  JxlColorEncoding color;
  ConvertInternalToExternalColorEncoding(color_encoding, &color);
  size_t num_pixels = 3 * image.xsize() * image.ysize();
  std::vector<uint16_t> pixels(num_pixels);
  const ImageF* channels[3];
  for (int c = 0; c < 3; ++c) {
    channels[c] = &float_image.Plane(c);
  }
  JXL_CHECK(ConvertChannelsToExternal(
      channels, 3, 16, false, JXL_BIG_ENDIAN, 6 * image.xsize(), nullptr,
      &pixels[0], 2 * num_pixels, PixelCallback(), Orientation::kIdentity));
  (*cparams.debug_image)(cparams.debug_image_opaque, label, image.xsize(),
                         image.ysize(), &color, &pixels[0]);
}

template <typename T>
void DumpPlaneNormalizedT(const CompressParams& cparams, const char* label,
                          const Plane<T>& image) {
  T min;
  T max;
  ImageMinMax(image, &min, &max);
  Image3B normalized(image.xsize(), image.ysize());
  for (size_t c = 0; c < 3; ++c) {
    float mul = min == max ? 0 : (255.0f / (max - min));
    for (size_t y = 0; y < image.ysize(); ++y) {
      const T* JXL_RESTRICT row_in = image.ConstRow(y);
      uint8_t* JXL_RESTRICT row_out = normalized.PlaneRow(c, y);
      for (size_t x = 0; x < image.xsize(); ++x) {
        row_out[x] = static_cast<uint8_t>((row_in[x] - min) * mul);
      }
    }
  }
  DumpImageT(cparams, label, ColorEncoding::SRGB(), normalized);
}

}  // namespace

void DumpImage(const CompressParams& cparams, const char* label,
               const Image3<float>& image) {
  DumpImageT(cparams, label, ColorEncoding::SRGB(), image);
}

void DumpImage(const CompressParams& cparams, const char* label,
               const Image3<uint8_t>& image) {
  DumpImageT(cparams, label, ColorEncoding::SRGB(), image);
}

void DumpXybImage(const CompressParams& cparams, const char* label,
                  const Image3F& image) {
  if (!cparams.debug_image) return;

  Image3F linear(image.xsize(), image.ysize());
  OpsinParams opsin_params;
  opsin_params.Init(kDefaultIntensityTarget);
  OpsinToLinear(image, Rect(linear), nullptr, &linear, opsin_params);

  DumpImageT(cparams, label, ColorEncoding::LinearSRGB(), linear);
}

void DumpPlaneNormalized(const CompressParams& cparams, const char* label,
                         const Plane<float>& image) {
  DumpPlaneNormalizedT(cparams, label, image);
}

void DumpPlaneNormalized(const CompressParams& cparams, const char* label,
                         const Plane<uint8_t>& image) {
  DumpPlaneNormalizedT(cparams, label, image);
}

}  // namespace jxl
