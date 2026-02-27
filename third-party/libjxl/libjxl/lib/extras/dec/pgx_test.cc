// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/dec/pgx.h"

#include "lib/extras/packed_image_convert.h"
#include "lib/jxl/image_bundle.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace extras {
namespace {

Span<const uint8_t> MakeSpan(const char* str) {
  return Span<const uint8_t>(reinterpret_cast<const uint8_t*>(str),
                             strlen(str));
}

TEST(CodecPGXTest, Test8bits) {
  std::string pgx = "PG ML + 8 2 3\npixels";

  PackedPixelFile ppf;
  ThreadPool* pool = nullptr;

  EXPECT_TRUE(DecodeImagePGX(MakeSpan(pgx.c_str()), ColorHints(), &ppf));
  CodecInOut io;
  EXPECT_TRUE(ConvertPackedPixelFileToCodecInOut(ppf, pool, &io));

  ScaleImage(255.f, io.Main().color());

  EXPECT_FALSE(io.metadata.m.bit_depth.floating_point_sample);
  EXPECT_EQ(8u, io.metadata.m.bit_depth.bits_per_sample);
  EXPECT_TRUE(io.metadata.m.color_encoding.IsGray());
  EXPECT_EQ(2u, io.xsize());
  EXPECT_EQ(3u, io.ysize());

  float eps = 1e-5;
  EXPECT_NEAR('p', io.Main().color()->Plane(0).Row(0)[0], eps);
  EXPECT_NEAR('i', io.Main().color()->Plane(0).Row(0)[1], eps);
  EXPECT_NEAR('x', io.Main().color()->Plane(0).Row(1)[0], eps);
  EXPECT_NEAR('e', io.Main().color()->Plane(0).Row(1)[1], eps);
  EXPECT_NEAR('l', io.Main().color()->Plane(0).Row(2)[0], eps);
  EXPECT_NEAR('s', io.Main().color()->Plane(0).Row(2)[1], eps);
}

TEST(CodecPGXTest, Test16bits) {
  std::string pgx = "PG ML + 16 2 3\np_i_x_e_l_s_";

  PackedPixelFile ppf;
  ThreadPool* pool = nullptr;

  EXPECT_TRUE(DecodeImagePGX(MakeSpan(pgx.c_str()), ColorHints(), &ppf));
  CodecInOut io;
  EXPECT_TRUE(ConvertPackedPixelFileToCodecInOut(ppf, pool, &io));

  ScaleImage(255.f, io.Main().color());

  EXPECT_FALSE(io.metadata.m.bit_depth.floating_point_sample);
  EXPECT_EQ(16u, io.metadata.m.bit_depth.bits_per_sample);
  EXPECT_TRUE(io.metadata.m.color_encoding.IsGray());
  EXPECT_EQ(2u, io.xsize());
  EXPECT_EQ(3u, io.ysize());

  // Comparing ~16-bit numbers in floats, only ~7 bits left.
  float eps = 1e-3;
  const auto& plane = io.Main().color()->Plane(0);
  EXPECT_NEAR(256.0f * 'p' + '_', plane.Row(0)[0] * 257, eps);
  EXPECT_NEAR(256.0f * 'i' + '_', plane.Row(0)[1] * 257, eps);
  EXPECT_NEAR(256.0f * 'x' + '_', plane.Row(1)[0] * 257, eps);
  EXPECT_NEAR(256.0f * 'e' + '_', plane.Row(1)[1] * 257, eps);
  EXPECT_NEAR(256.0f * 'l' + '_', plane.Row(2)[0] * 257, eps);
  EXPECT_NEAR(256.0f * 's' + '_', plane.Row(2)[1] * 257, eps);
}

}  // namespace
}  // namespace extras
}  // namespace jxl
