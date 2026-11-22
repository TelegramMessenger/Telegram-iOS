// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/color_encoding_internal.h"

#include <stdio.h>

#include "lib/jxl/encode_internal.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

TEST(ColorEncodingTest, RoundTripAll) {
  for (const test::ColorEncodingDescriptor& cdesc : test::AllEncodings()) {
    const ColorEncoding c_original = test::ColorEncodingFromDescriptor(cdesc);
    // Verify Set(Get) yields the same white point/primaries/gamma.
    {
      ColorEncoding c;
      EXPECT_TRUE(c.SetWhitePoint(c_original.GetWhitePoint()));
      EXPECT_EQ(c_original.white_point, c.white_point);
    }
    {
      ColorEncoding c;
      EXPECT_TRUE(c.SetPrimaries(c_original.GetPrimaries()));
      EXPECT_EQ(c_original.primaries, c.primaries);
    }
    if (c_original.tf.IsGamma()) {
      ColorEncoding c;
      EXPECT_TRUE(c.tf.SetGamma(c_original.tf.GetGamma()));
      EXPECT_TRUE(c_original.tf.IsSame(c.tf));
    }
  }
}

TEST(ColorEncodingTest, CustomWhitePoint) {
  ColorEncoding c;
  // Nonsensical values
  CIExy xy_in;
  xy_in.x = 0.8;
  xy_in.y = 0.01;
  EXPECT_TRUE(c.SetWhitePoint(xy_in));
  const CIExy xy = c.GetWhitePoint();

  ColorEncoding c2;
  EXPECT_TRUE(c2.SetWhitePoint(xy));
  EXPECT_TRUE(c.SameColorSpace(c2));
}

TEST(ColorEncodingTest, CustomPrimaries) {
  ColorEncoding c;
  PrimariesCIExy xy_in;
  // Nonsensical values
  xy_in.r.x = -0.01;
  xy_in.r.y = 0.2;
  xy_in.g.x = 0.4;
  xy_in.g.y = 0.401;
  xy_in.b.x = 1.1;
  xy_in.b.y = -1.2;
  EXPECT_TRUE(c.SetPrimaries(xy_in));
  const PrimariesCIExy xy = c.GetPrimaries();

  ColorEncoding c2;
  EXPECT_TRUE(c2.SetPrimaries(xy));
  EXPECT_TRUE(c.SameColorSpace(c2));
}

TEST(ColorEncodingTest, CustomGamma) {
  ColorEncoding c;
#ifndef JXL_CRASH_ON_ERROR
  EXPECT_FALSE(c.tf.SetGamma(0.0));
  EXPECT_FALSE(c.tf.SetGamma(-1E-6));
  EXPECT_FALSE(c.tf.SetGamma(1.001));
#endif
  EXPECT_TRUE(c.tf.SetGamma(1.0));
  EXPECT_FALSE(c.tf.IsGamma());
  EXPECT_TRUE(c.tf.IsLinear());

  EXPECT_TRUE(c.tf.SetGamma(0.123));
  EXPECT_TRUE(c.tf.IsGamma());
  const double gamma = c.tf.GetGamma();

  ColorEncoding c2;
  EXPECT_TRUE(c2.tf.SetGamma(gamma));
  EXPECT_TRUE(c.SameColorEncoding(c2));
  EXPECT_TRUE(c2.tf.IsGamma());
}

TEST(ColorEncodingTest, InternalExternalConversion) {
  ColorEncoding source_internal;
  JxlColorEncoding external;
  ColorEncoding destination_internal;

  for (int i = 0; i < 100; i++) {
    source_internal.SetColorSpace(static_cast<ColorSpace>(rand() % 4));
    CIExy wp;
    wp.x = (float(rand()) / float((RAND_MAX)) * 0.5) + 0.25;
    wp.y = (float(rand()) / float((RAND_MAX)) * 0.5) + 0.25;
    EXPECT_TRUE(source_internal.SetWhitePoint(wp));
    if (source_internal.HasPrimaries()) {
      PrimariesCIExy primaries;
      primaries.r.x = (float(rand()) / float((RAND_MAX)) * 0.5) + 0.25;
      primaries.r.y = (float(rand()) / float((RAND_MAX)) * 0.5) + 0.25;
      primaries.g.x = (float(rand()) / float((RAND_MAX)) * 0.5) + 0.25;
      primaries.g.y = (float(rand()) / float((RAND_MAX)) * 0.5) + 0.25;
      primaries.b.x = (float(rand()) / float((RAND_MAX)) * 0.5) + 0.25;
      primaries.b.y = (float(rand()) / float((RAND_MAX)) * 0.5) + 0.25;
      EXPECT_TRUE(source_internal.SetPrimaries(primaries));
    }
    CustomTransferFunction tf;
    EXPECT_TRUE(tf.SetGamma((float(rand()) / float((RAND_MAX)) * 0.5) + 0.25));
    source_internal.tf = tf;
    source_internal.rendering_intent = static_cast<RenderingIntent>(rand() % 4);

    ConvertInternalToExternalColorEncoding(source_internal, &external);
    EXPECT_TRUE(ConvertExternalToInternalColorEncoding(external,
                                                       &destination_internal));

    EXPECT_EQ(source_internal.GetColorSpace(),
              destination_internal.GetColorSpace());
    EXPECT_EQ(source_internal.white_point, destination_internal.white_point);
    EXPECT_EQ(source_internal.GetWhitePoint().x,
              destination_internal.GetWhitePoint().x);
    EXPECT_EQ(source_internal.GetWhitePoint().y,
              destination_internal.GetWhitePoint().y);
    if (source_internal.HasPrimaries()) {
      EXPECT_EQ(source_internal.GetPrimaries().r.x,
                destination_internal.GetPrimaries().r.x);
      EXPECT_EQ(source_internal.GetPrimaries().r.y,
                destination_internal.GetPrimaries().r.y);
      EXPECT_EQ(source_internal.GetPrimaries().g.x,
                destination_internal.GetPrimaries().g.x);
      EXPECT_EQ(source_internal.GetPrimaries().g.y,
                destination_internal.GetPrimaries().g.y);
      EXPECT_EQ(source_internal.GetPrimaries().b.x,
                destination_internal.GetPrimaries().b.x);
      EXPECT_EQ(source_internal.GetPrimaries().b.y,
                destination_internal.GetPrimaries().b.y);
    }
    EXPECT_EQ(source_internal.tf.IsGamma(), destination_internal.tf.IsGamma());
    if (source_internal.tf.IsGamma()) {
      EXPECT_EQ(source_internal.tf.GetGamma(),
                destination_internal.tf.GetGamma());
    } else {
      EXPECT_EQ(source_internal.tf.GetTransferFunction(),
                destination_internal.tf.GetTransferFunction());
    }
    EXPECT_EQ(source_internal.rendering_intent,
              destination_internal.rendering_intent);
  }
}

}  // namespace
}  // namespace jxl
