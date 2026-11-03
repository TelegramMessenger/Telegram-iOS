// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_external_image.h"

#include <array>
#include <new>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/image_ops.h"
#include "lib/jxl/image_test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

#if !defined(JXL_CRASH_ON_ERROR)
TEST(ExternalImageTest, InvalidSize) {
  ImageMetadata im;
  im.SetAlphaBits(8);
  ImageBundle ib(&im);

  JxlPixelFormat format = {4, JXL_TYPE_UINT16, JXL_BIG_ENDIAN, 0};
  const uint8_t buf[10 * 100 * 8] = {};
  EXPECT_FALSE(ConvertFromExternal(
      Span<const uint8_t>(buf, 10), /*xsize=*/10, /*ysize=*/100,
      /*c_current=*/ColorEncoding::SRGB(),
      /*bits_per_sample=*/16, format, nullptr, &ib));
  EXPECT_FALSE(ConvertFromExternal(
      Span<const uint8_t>(buf, sizeof(buf) - 1), /*xsize=*/10, /*ysize=*/100,
      /*c_current=*/ColorEncoding::SRGB(),
      /*bits_per_sample=*/16, format, nullptr, &ib));
  EXPECT_TRUE(
      ConvertFromExternal(Span<const uint8_t>(buf, sizeof(buf)), /*xsize=*/10,
                          /*ysize=*/100, /*c_current=*/ColorEncoding::SRGB(),
                          /*bits_per_sample=*/16, format, nullptr, &ib));
}
#endif

TEST(ExternalImageTest, AlphaMissing) {
  ImageMetadata im;
  im.SetAlphaBits(0);  // No alpha
  ImageBundle ib(&im);

  const size_t xsize = 10;
  const size_t ysize = 20;
  const uint8_t buf[xsize * ysize * 4] = {};

  JxlPixelFormat format = {4, JXL_TYPE_UINT8, JXL_BIG_ENDIAN, 0};
  // has_alpha is true but the ImageBundle has no alpha. Alpha channel should
  // be ignored.
  EXPECT_TRUE(ConvertFromExternal(Span<const uint8_t>(buf, sizeof(buf)), xsize,
                                  ysize,
                                  /*c_current=*/ColorEncoding::SRGB(),
                                  /*bits_per_sample=*/8, format, nullptr, &ib));
  EXPECT_FALSE(ib.HasAlpha());
}

TEST(ExternalImageTest, AlphaPremultiplied) {
  ImageMetadata im;
  im.SetAlphaBits(8, true);

  ImageBundle ib(&im);
  const size_t xsize = 10;
  const size_t ysize = 20;
  const size_t size = xsize * ysize * 8;
  const uint8_t buf[size] = {};

  JxlPixelFormat format = {4, JXL_TYPE_UINT16, JXL_BIG_ENDIAN, 0};
  EXPECT_TRUE(BufferToImageBundle(format, xsize, ysize, buf, size, nullptr,
                                  ColorEncoding::SRGB(), &ib));
}

}  // namespace
}  // namespace jxl
