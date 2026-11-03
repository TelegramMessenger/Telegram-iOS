// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/color_management.h"

#include <stdint.h>
#include <stdio.h>

#include <algorithm>
#include <new>
#include <string>
#include <utility>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/random.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_xyb.h"
#include "lib/jxl/image_test_utils.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {

std::ostream& operator<<(std::ostream& os, const CIExy& xy) {
  return os << "{x=" << xy.x << ", y=" << xy.y << "}";
}

std::ostream& operator<<(std::ostream& os, const PrimariesCIExy& primaries) {
  return os << "{r=" << primaries.r << ", g=" << primaries.g
            << ", b=" << primaries.b << "}";
}

namespace {

using ::testing::ElementsAre;
using ::testing::FloatNear;

// Small enough to be fast. If changed, must update Generate*.
static constexpr size_t kWidth = 16;

static constexpr size_t kNumThreads = 1;  // only have a single row.

MATCHER_P(HasSameFieldsAs, expected, "") {
  if (arg.rendering_intent != expected.rendering_intent) {
    *result_listener << "which has a different rendering intent: "
                     << ToString(arg.rendering_intent) << " instead of "
                     << ToString(expected.rendering_intent);
    return false;
  }
  if (arg.GetColorSpace() != expected.GetColorSpace()) {
    *result_listener << "which has a different color space: "
                     << ToString(arg.GetColorSpace()) << " instead of "
                     << ToString(expected.GetColorSpace());
    return false;
  }
  if (arg.white_point != expected.white_point) {
    *result_listener << "which has a different white point: "
                     << ToString(arg.white_point) << " instead of "
                     << ToString(expected.white_point);
    return false;
  }
  if (arg.HasPrimaries() && arg.primaries != expected.primaries) {
    *result_listener << "which has different primaries: "
                     << ToString(arg.primaries) << " instead of "
                     << ToString(expected.primaries);
    return false;
  }
  if (!arg.tf.IsSame(expected.tf)) {
    static const auto tf_to_string = [](const CustomTransferFunction& tf) {
      if (tf.IsGamma()) {
        return "g" + ToString(tf.GetGamma());
      }
      return ToString(tf.GetTransferFunction());
    };
    *result_listener << "which has a different transfer function: "
                     << tf_to_string(arg.tf) << " instead of "
                     << tf_to_string(expected.tf);
    return false;
  }
  return true;
}

struct Globals {
  // TODO(deymo): Make this a const.
  static Globals* GetInstance() {
    static Globals ret;
    return &ret;
  }

 private:
  Globals() {
    in_gray = GenerateGray();
    in_color = GenerateColor();
    out_gray = ImageF(kWidth, 1);
    out_color = ImageF(kWidth * 3, 1);

    c_native = ColorEncoding::LinearSRGB(/*is_gray=*/false);
    c_gray = ColorEncoding::LinearSRGB(/*is_gray=*/true);
  }

  static ImageF GenerateGray() {
    ImageF gray(kWidth, 1);
    float* JXL_RESTRICT row = gray.Row(0);
    // Increasing left to right
    for (uint32_t x = 0; x < kWidth; ++x) {
      row[x] = x * 1.0f / (kWidth - 1);  // [0, 1]
    }
    return gray;
  }

  static ImageF GenerateColor() {
    ImageF image(kWidth * 3, 1);
    float* JXL_RESTRICT interleaved = image.Row(0);
    std::fill(interleaved, interleaved + kWidth * 3, 0.0f);

    // [0, 4): neutral
    for (int32_t x = 0; x < 4; ++x) {
      interleaved[3 * x + 0] = x * 1.0f / 3;  // [0, 1]
      interleaved[3 * x + 2] = interleaved[3 * x + 1] = interleaved[3 * x + 0];
    }

    // [4, 13): pure RGB with low/medium/high saturation
    for (int32_t c = 0; c < 3; ++c) {
      interleaved[3 * (4 + c) + c] = 0.08f + c * 0.01f;
      interleaved[3 * (7 + c) + c] = 0.75f + c * 0.01f;
      interleaved[3 * (10 + c) + c] = 1.0f;
    }

    // [13, 16): impure, not quite saturated RGB
    interleaved[3 * 13 + 0] = 0.86f;
    interleaved[3 * 13 + 2] = interleaved[3 * 13 + 1] = 0.16f;
    interleaved[3 * 14 + 1] = 0.87f;
    interleaved[3 * 14 + 2] = interleaved[3 * 14 + 0] = 0.16f;
    interleaved[3 * 15 + 2] = 0.88f;
    interleaved[3 * 15 + 1] = interleaved[3 * 15 + 0] = 0.16f;

    return image;
  }

 public:
  // ImageF so we can use VerifyRelativeError; all are interleaved RGB.
  ImageF in_gray;
  ImageF in_color;
  ImageF out_gray;
  ImageF out_color;
  ColorEncoding c_native;
  ColorEncoding c_gray;
};

class ColorManagementTest
    : public ::testing::TestWithParam<test::ColorEncodingDescriptor> {
 public:
  // "Same" pixels after converting g->c_native -> c -> g->c_native.
  static void VerifyPixelRoundTrip(const ColorEncoding& c) {
    Globals* g = Globals::GetInstance();
    const ColorEncoding& c_native = c.IsGray() ? g->c_gray : g->c_native;
    const JxlCmsInterface& cms = GetJxlCms();
    ColorSpaceTransform xform_fwd(cms);
    ColorSpaceTransform xform_rev(cms);
    const float intensity_target =
        c.tf.IsHLG() ? 1000 : kDefaultIntensityTarget;
    ASSERT_TRUE(
        xform_fwd.Init(c_native, c, intensity_target, kWidth, kNumThreads));
    ASSERT_TRUE(
        xform_rev.Init(c, c_native, intensity_target, kWidth, kNumThreads));

    const size_t thread = 0;
    const ImageF& in = c.IsGray() ? g->in_gray : g->in_color;
    ImageF* JXL_RESTRICT out = c.IsGray() ? &g->out_gray : &g->out_color;
    ASSERT_TRUE(xform_fwd.Run(thread, in.Row(0), xform_fwd.BufDst(thread)));
    ASSERT_TRUE(xform_rev.Run(thread, xform_fwd.BufDst(thread), out->Row(0)));

#if JPEGXL_ENABLE_SKCMS
    double max_l1 = 7E-4;
    double max_rel = 4E-7;
#else
    double max_l1 = 5E-5;
    // Most are lower; reached 3E-7 with D60 AP0.
    double max_rel = 4E-7;
#endif
    if (c.IsGray()) max_rel = 2E-5;
    JXL_ASSERT_OK(VerifyRelativeError(in, *out, max_l1, max_rel, _));
  }
};
JXL_GTEST_INSTANTIATE_TEST_SUITE_P(ColorManagementTestInstantiation,
                                   ColorManagementTest,
                                   ::testing::ValuesIn(test::AllEncodings()));

// Exercises the ColorManagement interface for ALL ColorEncoding synthesizable
// via enums.
TEST_P(ColorManagementTest, VerifyAllProfiles) {
  ColorEncoding c = ColorEncodingFromDescriptor(GetParam());
  printf("%s\n", Description(c).c_str());

  // Can create profile.
  ASSERT_TRUE(c.CreateICC());

  // Can set an equivalent ColorEncoding from the generated ICC profile.
  ColorEncoding c3;
  ASSERT_TRUE(c3.SetICC(PaddedBytes(c.ICC()), &GetJxlCms()));
  EXPECT_THAT(c3, HasSameFieldsAs(c));

  VerifyPixelRoundTrip(c);
}

testing::Matcher<CIExy> CIExyIs(const double x, const double y) {
  static constexpr double kMaxError = 1e-4;
  return testing::AllOf(
      testing::Field(&CIExy::x, testing::DoubleNear(x, kMaxError)),
      testing::Field(&CIExy::y, testing::DoubleNear(y, kMaxError)));
}

testing::Matcher<PrimariesCIExy> PrimariesAre(
    const testing::Matcher<CIExy>& r, const testing::Matcher<CIExy>& g,
    const testing::Matcher<CIExy>& b) {
  return testing::AllOf(testing::Field(&PrimariesCIExy::r, r),
                        testing::Field(&PrimariesCIExy::g, g),
                        testing::Field(&PrimariesCIExy::b, b));
}

TEST_F(ColorManagementTest, sRGBChromaticity) {
  const ColorEncoding sRGB = ColorEncoding::SRGB();
  EXPECT_THAT(sRGB.GetWhitePoint(), CIExyIs(0.3127, 0.3290));
  EXPECT_THAT(sRGB.GetPrimaries(),
              PrimariesAre(CIExyIs(0.64, 0.33), CIExyIs(0.30, 0.60),
                           CIExyIs(0.15, 0.06)));
}

TEST_F(ColorManagementTest, D2700Chromaticity) {
  PaddedBytes icc =
      jxl::test::ReadTestData("jxl/color_management/sRGB-D2700.icc");
  ColorEncoding sRGB_D2700;
  ASSERT_TRUE(sRGB_D2700.SetICC(std::move(icc), &GetJxlCms()));

  EXPECT_THAT(sRGB_D2700.GetWhitePoint(), CIExyIs(0.45986, 0.41060));
  // The illuminant-relative chromaticities of this profile's primaries are the
  // same as for sRGB. It is the PCS-relative chromaticities that would be
  // different.
  EXPECT_THAT(sRGB_D2700.GetPrimaries(),
              PrimariesAre(CIExyIs(0.64, 0.33), CIExyIs(0.30, 0.60),
                           CIExyIs(0.15, 0.06)));
}

TEST_F(ColorManagementTest, D2700ToSRGB) {
  const JxlCmsInterface& cms = GetJxlCms();
  PaddedBytes icc =
      jxl::test::ReadTestData("jxl/color_management/sRGB-D2700.icc");
  ColorEncoding sRGB_D2700;
  ASSERT_TRUE(sRGB_D2700.SetICC(std::move(icc), &cms));

  ColorSpaceTransform transform(cms);
  ASSERT_TRUE(transform.Init(sRGB_D2700, ColorEncoding::SRGB(),
                             kDefaultIntensityTarget, 1, 1));
  const float sRGB_D2700_values[3] = {0.863, 0.737, 0.490};
  float sRGB_values[3];
  ASSERT_TRUE(transform.Run(0, sRGB_D2700_values, sRGB_values));
  EXPECT_THAT(sRGB_values,
              ElementsAre(FloatNear(0.914, 1e-3), FloatNear(0.745, 1e-3),
                          FloatNear(0.601, 1e-3)));
}

TEST_F(ColorManagementTest, P3HlgTo2020Hlg) {
  ColorEncoding p3_hlg;
  p3_hlg.SetColorSpace(ColorSpace::kRGB);
  p3_hlg.white_point = WhitePoint::kD65;
  p3_hlg.primaries = Primaries::kP3;
  p3_hlg.tf.SetTransferFunction(TransferFunction::kHLG);
  ASSERT_TRUE(p3_hlg.CreateICC());

  ColorEncoding rec2020_hlg = p3_hlg;
  rec2020_hlg.primaries = Primaries::k2100;
  ASSERT_TRUE(rec2020_hlg.CreateICC());

  ColorSpaceTransform transform(GetJxlCms());
  ASSERT_TRUE(transform.Init(p3_hlg, rec2020_hlg, 1000, 1, 1));
  const float p3_hlg_values[3] = {0., 0.75, 0.};
  float rec2020_hlg_values[3];
  ASSERT_TRUE(transform.Run(0, p3_hlg_values, rec2020_hlg_values));
  EXPECT_THAT(rec2020_hlg_values,
              ElementsAre(FloatNear(0.3973, 1e-4), FloatNear(0.7382, 1e-4),
                          FloatNear(0.1183, 1e-4)));
}

TEST_F(ColorManagementTest, HlgOotf) {
  ColorEncoding p3_hlg;
  p3_hlg.SetColorSpace(ColorSpace::kRGB);
  p3_hlg.white_point = WhitePoint::kD65;
  p3_hlg.primaries = Primaries::kP3;
  p3_hlg.tf.SetTransferFunction(TransferFunction::kHLG);
  ASSERT_TRUE(p3_hlg.CreateICC());

  ColorSpaceTransform transform_to_1000(GetJxlCms());
  ASSERT_TRUE(
      transform_to_1000.Init(p3_hlg, ColorEncoding::LinearSRGB(), 1000, 1, 1));
  // HDR reference white: https://www.itu.int/pub/R-REP-BT.2408-4-2021
  float p3_hlg_values[3] = {0.75, 0.75, 0.75};
  float linear_srgb_values[3];
  ASSERT_TRUE(transform_to_1000.Run(0, p3_hlg_values, linear_srgb_values));
  // On a 1000-nit display, HDR reference white should be 203 cd/m² which is
  // 0.203 times the maximum.
  EXPECT_THAT(linear_srgb_values,
              ElementsAre(FloatNear(0.203, 1e-3), FloatNear(0.203, 1e-3),
                          FloatNear(0.203, 1e-3)));

  ColorSpaceTransform transform_to_400(GetJxlCms());
  ASSERT_TRUE(
      transform_to_400.Init(p3_hlg, ColorEncoding::LinearSRGB(), 400, 1, 1));
  ASSERT_TRUE(transform_to_400.Run(0, p3_hlg_values, linear_srgb_values));
  // On a 400-nit display, it should be 100 cd/m².
  EXPECT_THAT(linear_srgb_values,
              ElementsAre(FloatNear(0.250, 1e-3), FloatNear(0.250, 1e-3),
                          FloatNear(0.250, 1e-3)));

  p3_hlg_values[2] = 0.50;
  ASSERT_TRUE(transform_to_1000.Run(0, p3_hlg_values, linear_srgb_values));
  EXPECT_THAT(linear_srgb_values,
              ElementsAre(FloatNear(0.201, 1e-3), FloatNear(0.201, 1e-3),
                          FloatNear(0.050, 1e-3)));

  ColorSpaceTransform transform_from_400(GetJxlCms());
  ASSERT_TRUE(
      transform_from_400.Init(ColorEncoding::LinearSRGB(), p3_hlg, 400, 1, 1));
  linear_srgb_values[0] = linear_srgb_values[1] = linear_srgb_values[2] = 0.250;
  ASSERT_TRUE(transform_from_400.Run(0, linear_srgb_values, p3_hlg_values));
  EXPECT_THAT(p3_hlg_values,
              ElementsAre(FloatNear(0.75, 1e-3), FloatNear(0.75, 1e-3),
                          FloatNear(0.75, 1e-3)));

  ColorEncoding grayscale_hlg;
  grayscale_hlg.SetColorSpace(ColorSpace::kGray);
  grayscale_hlg.white_point = WhitePoint::kD65;
  grayscale_hlg.tf.SetTransferFunction(TransferFunction::kHLG);
  ASSERT_TRUE(grayscale_hlg.CreateICC());

  ColorSpaceTransform grayscale_transform(GetJxlCms());
  ASSERT_TRUE(grayscale_transform.Init(
      grayscale_hlg, ColorEncoding::LinearSRGB(/*is_gray=*/true), 1000, 1, 1));
  const float grayscale_hlg_value = 0.75;
  float linear_grayscale_value;
  ASSERT_TRUE(grayscale_transform.Run(0, &grayscale_hlg_value,
                                      &linear_grayscale_value));
  EXPECT_THAT(linear_grayscale_value, FloatNear(0.203, 1e-3));
}

TEST_F(ColorManagementTest, XYBProfile) {
  ColorEncoding c_xyb;
  c_xyb.SetColorSpace(ColorSpace::kXYB);
  c_xyb.rendering_intent = RenderingIntent::kPerceptual;
  ASSERT_TRUE(c_xyb.CreateICC());
  ColorEncoding c_native = ColorEncoding::LinearSRGB(false);

  static const size_t kGridDim = 17;
  static const size_t kNumColors = kGridDim * kGridDim * kGridDim;
  const JxlCmsInterface& cms = GetJxlCms();
  ColorSpaceTransform xform(cms);
  ASSERT_TRUE(
      xform.Init(c_xyb, c_native, kDefaultIntensityTarget, kNumColors, 1));

  ImageMetadata metadata;
  metadata.color_encoding = c_native;
  ImageBundle ib(&metadata);
  Image3F native(kNumColors, 1);
  float mul = 1.0f / (kGridDim - 1);
  for (size_t ir = 0, x = 0; ir < kGridDim; ++ir) {
    for (size_t ig = 0; ig < kGridDim; ++ig) {
      for (size_t ib = 0; ib < kGridDim; ++ib, ++x) {
        native.PlaneRow(0, 0)[x] = ir * mul;
        native.PlaneRow(1, 0)[x] = ig * mul;
        native.PlaneRow(2, 0)[x] = ib * mul;
      }
    }
  }
  ib.SetFromImage(std::move(native), c_native);
  const Image3F& in = *ib.color();
  Image3F opsin(kNumColors, 1);
  ToXYB(ib, nullptr, &opsin, cms, nullptr);

  Image3F opsin2(kNumColors, 1);
  CopyImageTo(opsin, &opsin2);
  ScaleXYB(&opsin2);

  float* src = xform.BufSrc(0);
  for (size_t i = 0; i < kNumColors; ++i) {
    for (size_t c = 0; c < 3; ++c) {
      src[3 * i + c] = opsin2.PlaneRow(c, 0)[i];
    }
  }

  float* dst = xform.BufDst(0);
  ASSERT_TRUE(xform.Run(0, src, dst));

  Image3F out(kNumColors, 1);
  for (size_t i = 0; i < kNumColors; ++i) {
    for (size_t c = 0; c < 3; ++c) {
      out.PlaneRow(c, 0)[i] = dst[3 * i + c];
    }
  }

  auto debug_print_color = [&](size_t i) {
    printf(
        "(%f, %f, %f) -> (%9.6f, %f, %f) -> (%f, %f, %f) -> "
        "(%9.6f, %9.6f, %9.6f)",
        in.PlaneRow(0, 0)[i], in.PlaneRow(1, 0)[i], in.PlaneRow(2, 0)[i],
        opsin.PlaneRow(0, 0)[i], opsin.PlaneRow(1, 0)[i],
        opsin.PlaneRow(2, 0)[i], opsin2.PlaneRow(0, 0)[i],
        opsin2.PlaneRow(1, 0)[i], opsin2.PlaneRow(2, 0)[i],
        out.PlaneRow(0, 0)[i], out.PlaneRow(1, 0)[i], out.PlaneRow(2, 0)[i]);
  };

  float max_err[3] = {};
  size_t max_err_i[3] = {};
  for (size_t i = 0; i < kNumColors; ++i) {
    for (size_t c = 0; c < 3; ++c) {
      // debug_print_color(i); printf("\n");
      float err = std::abs(in.PlaneRow(c, 0)[i] - out.PlaneRow(c, 0)[i]);
      if (err > max_err[c]) {
        max_err[c] = err;
        max_err_i[c] = i;
      }
    }
  }
  static float kMaxError[3] = {9e-4, 4e-4, 5e-4};
  printf("Maximum errors:\n");
  for (size_t c = 0; c < 3; ++c) {
    debug_print_color(max_err_i[c]);
    printf("    %f\n", max_err[c]);
    EXPECT_LT(max_err[c], kMaxError[c]);
  }
}

}  // namespace
}  // namespace jxl
