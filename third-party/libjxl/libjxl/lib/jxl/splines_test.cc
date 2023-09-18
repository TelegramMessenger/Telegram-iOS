// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/splines.h"

#include "lib/extras/codec.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/enc_butteraugli_comparator.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_splines.h"
#include "lib/jxl/image_test_utils.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {

std::ostream& operator<<(std::ostream& os, const Spline::Point& p) {
  return os << "(" << p.x << ", " << p.y << ")";
}

std::ostream& operator<<(std::ostream& os, const Spline& spline) {
  return os << "(spline with " << spline.control_points.size()
            << " control points)";
}

namespace {

using ::testing::AllOf;
using ::testing::Field;
using ::testing::FloatNear;
using ::testing::Pointwise;

constexpr int kQuantizationAdjustment = 0;
const ColorCorrelationMap* const cmap = new ColorCorrelationMap;
const float kYToX = cmap->YtoXRatio(0);
const float kYToB = cmap->YtoBRatio(0);

constexpr float kTolerance = 0.003125;

std::vector<Spline> DequantizeSplines(const Splines& splines) {
  const auto& quantized_splines = splines.QuantizedSplines();
  const auto& starting_points = splines.StartingPoints();
  JXL_CHECK(quantized_splines.size() == starting_points.size());

  std::vector<Spline> dequantized;
  uint64_t total = 0;
  for (size_t i = 0; i < quantized_splines.size(); ++i) {
    dequantized.emplace_back();
    JXL_CHECK(quantized_splines[i].Dequantize(
        starting_points[i], kQuantizationAdjustment, kYToX, kYToB, 2u << 30u,
        &total, dequantized.back()));
  }
  return dequantized;
}

MATCHER(ControlPointIs, "") {
  const Spline::Point& actual = std::get<0>(arg);
  const Spline::Point& expected = std::get<1>(arg);
  return testing::ExplainMatchResult(
      AllOf(Field(&Spline::Point::x, FloatNear(expected.x, kTolerance)),
            Field(&Spline::Point::y, FloatNear(expected.y, kTolerance))),
      actual, result_listener);
}

MATCHER(ControlPointsMatch, "") {
  const Spline& actual = std::get<0>(arg);
  const Spline& expected = std::get<1>(arg);
  return testing::ExplainMatchResult(
      Field(&Spline::control_points,
            Pointwise(ControlPointIs(), expected.control_points)),
      actual, result_listener);
}

MATCHER(SplinesMatch, "") {
  const Spline& actual = std::get<0>(arg);
  const Spline& expected = std::get<1>(arg);
  if (!testing::ExplainMatchResult(ControlPointsMatch(), arg,
                                   result_listener)) {
    return false;
  }
  for (int i = 0; i < 3; ++i) {
    size_t color_dct_size =
        sizeof(expected.color_dct[i]) / sizeof(expected.color_dct[i][0]);
    for (size_t j = 0; j < color_dct_size; j++) {
      testing::StringMatchResultListener color_dct_listener;
      if (!testing::ExplainMatchResult(
              FloatNear(expected.color_dct[i][j], kTolerance),
              actual.color_dct[i][j], &color_dct_listener)) {
        *result_listener << ", where color_dct[" << i << "][" << j
                         << "] don't match, " << color_dct_listener.str();
        return false;
      }
    }
  }
  size_t sigma_dct_size =
      sizeof(expected.sigma_dct) / sizeof(expected.sigma_dct[0]);
  for (size_t i = 0; i < sigma_dct_size; i++) {
    testing::StringMatchResultListener sigma_listener;
    if (!testing::ExplainMatchResult(
            FloatNear(expected.sigma_dct[i], kTolerance), actual.sigma_dct[i],
            &sigma_listener)) {
      *result_listener << ", where sigma_dct[" << i << "] don't match, "
                       << sigma_listener.str();
      return false;
    }
  }
  return true;
}

}  // namespace

TEST(SplinesTest, Serialization) {
  std::vector<Spline> spline_data = {
      {/*control_points=*/{
           {109, 54}, {218, 159}, {80, 3}, {110, 274}, {94, 185}, {17, 277}},
       /*color_dct=*/
       {{36.3, 39.7, 23.2, 67.5, 4.4,  71.5, 62.3, 32.3, 92.2, 10.1, 10.8,
         9.2,  6.1,  10.5, 79.1, 7,    24.6, 90.8, 5.5,  84,   43.8, 49,
         33.5, 78.9, 54.5, 77.9, 62.1, 51.4, 36.4, 14.3, 83.7, 35.4},
        {9.4,  53.4, 9.5,  74.9, 72.7, 26.7, 7.9,  0.9, 84.9, 23.2, 26.5,
         31.1, 91,   11.7, 74.1, 39.3, 23.7, 82.5, 4.8, 2.7,  61.2, 96.4,
         13.7, 66.7, 62.9, 82.4, 5.9,  98.7, 21.5, 7.9, 51.7, 63.1},
        {48,   39.3, 6.9,  26.3, 33.3, 6.2,  1.7,  98.9, 59.9, 59.6, 95,
         61.3, 82.7, 53,   6.1,  30.4, 34.7, 96.9, 93.4, 17,   38.8, 80.8,
         63,   18.6, 43.6, 32.3, 61,   20.2, 24.3, 28.3, 69.1, 62.4}},
       /*sigma_dct=*/{32.7, 21.5, 44.4, 1.8,  45.8, 90.6, 29.3, 59.2,
                      23.7, 85.2, 84.8, 27.2, 42.1, 84.1, 50.6, 17.6,
                      93.7, 4.9,  2.6,  69.8, 94.9, 52,   24.3, 18.8,
                      12.1, 95.7, 28.5, 81.4, 89.9, 31.4, 74.8, 52}},
      {/*control_points=*/{{172, 309},
                           {196, 277},
                           {42, 238},
                           {114, 350},
                           {307, 290},
                           {316, 269},
                           {124, 66},
                           {233, 267}},
       /*color_dct=*/
       {{15,   28.9, 22, 6.6,  41.8, 83,   8.6,  56.8, 68.9, 9.7,  5.4,
         19.8, 70.8, 90, 52.5, 65.2, 7.8,  23.5, 26.4, 72.2, 64.7, 87.1,
         1.3,  67.5, 46, 68.4, 65.4, 35.5, 29.1, 13,   41.6, 23.9},
        {47.7, 79.4, 62.7, 29.1, 96.8, 18.5, 17.6, 15.2, 80.5, 56,  96.2,
         59.9, 26.7, 96.1, 92.3, 42.1, 35.8, 54,   23.2, 55,   76,  35.8,
         58.4, 88.7, 2.4,  78.1, 95.6, 27.5, 6.6,  78.5, 24.1, 69.8},
        {43.8, 96.5, 0.9,  95.1, 49.1, 71.2, 25.1, 33.6, 75.2, 95,  82.1,
         19.7, 10.5, 44.9, 50,   93.3, 83.5, 99.5, 64.6, 54,   3.5, 99.7,
         45.3, 82.1, 22.4, 37.9, 60,   32.2, 12.6, 4.6,  65.5, 96.4}},
       /*sigma_dct=*/{72.5, 2.6,  41.7, 2.2,  39.7, 79.1, 69.6, 19.9,
                      92.3, 71.5, 41.9, 62.1, 30,   49.4, 70.3, 45.3,
                      62.5, 47.2, 46.7, 41.2, 90.8, 46.8, 91.2, 55,
                      8.1,  69.6, 25.4, 84.7, 61.7, 27.6, 3.7,  46.9}},
      {/*control_points=*/{{100, 186},
                           {257, 97},
                           {170, 49},
                           {25, 169},
                           {309, 104},
                           {232, 237},
                           {385, 101},
                           {122, 168},
                           {26, 300},
                           {390, 88}},
       /*color_dct=*/
       {{16.9, 64.8, 4.2,  10.6, 23.5, 17,   79.3, 5.7,  60.4, 16.6, 94.9,
         63.7, 87.6, 10.5, 3.8,  61.1, 22.9, 81.9, 80.4, 40.5, 45.9, 25.4,
         39.8, 30,   50.2, 90.4, 27.9, 93.7, 65.1, 48.2, 22.3, 43.9},
        {24.9, 66,   3.5,  90.2, 97.1, 15.8, 35.6, 0.6,  68,   39.6, 24.4,
         85.9, 57.7, 77.6, 47.5, 67.9, 4.3,  5.4,  91.2, 58.5, 0.1,  52.2,
         3.5,  47.8, 63.2, 43.5, 85.8, 35.8, 50.2, 35.9, 19.2, 48.2},
        {82.8, 44.9, 76.4, 39.5, 94.1, 14.3, 89.8, 10,   10.5, 74.5, 56.3,
         65.8, 7.8,  23.3, 52.8, 99.3, 56.8, 46,   76.7, 13.5, 67,   22.4,
         29.9, 43.3, 70.3, 26,   74.3, 53.9, 62,   19.1, 49.3, 46.7}},
       /*sigma_dct=*/{83.5, 1.7,  25.1, 18.7, 46.5, 75.3, 28,   62.3,
                      50.3, 23.3, 85.6, 96,   45.8, 33.1, 33.4, 52.9,
                      26.3, 58.5, 19.6, 70,   92.6, 22.5, 57,   21.6,
                      76.8, 87.5, 22.9, 66.3, 35.7, 35.6, 56.8, 67.2}},
  };

  std::vector<QuantizedSpline> quantized_splines;
  std::vector<Spline::Point> starting_points;
  for (const Spline& spline : spline_data) {
    quantized_splines.emplace_back(spline, kQuantizationAdjustment, kYToX,
                                   kYToB);
    starting_points.push_back(spline.control_points.front());
  }

  Splines splines(kQuantizationAdjustment, std::move(quantized_splines),
                  std::move(starting_points));
  const std::vector<Spline> quantized_spline_data = DequantizeSplines(splines);
  EXPECT_THAT(quantized_spline_data,
              Pointwise(ControlPointsMatch(), spline_data));

  BitWriter writer;
  EncodeSplines(splines, &writer, kLayerSplines, HistogramParams(), nullptr);
  writer.ZeroPadToByte();
  const size_t bits_written = writer.BitsWritten();

  printf("Wrote %" PRIuS " bits of splines.\n", bits_written);

  BitReader reader(writer.GetSpan());
  Splines decoded_splines;
  ASSERT_TRUE(decoded_splines.Decode(&reader, /*num_pixels=*/1000));
  ASSERT_TRUE(reader.JumpToByteBoundary());
  EXPECT_EQ(reader.TotalBitsConsumed(), bits_written);
  ASSERT_TRUE(reader.Close());

  const std::vector<Spline> decoded_spline_data =
      DequantizeSplines(decoded_splines);
  EXPECT_THAT(decoded_spline_data,
              Pointwise(SplinesMatch(), quantized_spline_data));
}

#ifdef JXL_CRASH_ON_ERROR
TEST(SplinesTest, DISABLED_TooManySplinesTest) {
#else
TEST(SplinesTest, TooManySplinesTest) {
#endif
  // This is more than the limit for 1000 pixels.
  const size_t kNumSplines = 300;

  std::vector<QuantizedSpline> quantized_splines;
  std::vector<Spline::Point> starting_points;
  for (size_t i = 0; i < kNumSplines; i++) {
    Spline spline = {
        /*control_points=*/{{1.f + i, 2}, {10.f + i, 25}, {30.f + i, 300}},
        /*color_dct=*/
        {{1.f, 0.2f, 0.1f}, {35.7f, 10.3f}, {35.7f, 7.8f}},
        /*sigma_dct=*/{10.f, 0.f, 0.f, 2.f}};
    quantized_splines.emplace_back(spline, kQuantizationAdjustment, kYToX,
                                   kYToB);
    starting_points.push_back(spline.control_points.front());
  }

  Splines splines(kQuantizationAdjustment, std::move(quantized_splines),
                  std::move(starting_points));
  BitWriter writer;
  EncodeSplines(splines, &writer, kLayerSplines,
                HistogramParams(SpeedTier::kFalcon, 1), nullptr);
  writer.ZeroPadToByte();
  // Re-read splines.
  BitReader reader(writer.GetSpan());
  Splines decoded_splines;
  EXPECT_FALSE(decoded_splines.Decode(&reader, /*num_pixels=*/1000));
  EXPECT_TRUE(reader.Close());
}

#ifdef JXL_CRASH_ON_ERROR
TEST(SplinesTest, DISABLED_DuplicatePoints) {
#else
TEST(SplinesTest, DuplicatePoints) {
#endif
  std::vector<Spline::Point> control_points{
      {9, 54}, {118, 159}, {97, 3},  // Repeated.
      {97, 3}, {10, 40},   {150, 25}, {120, 300}};
  Spline spline{control_points,
                /*color_dct=*/
                {{1.f, 0.2f, 0.1f}, {35.7f, 10.3f}, {35.7f, 7.8f}},
                /*sigma_dct=*/{10.f, 0.f, 0.f, 2.f}};
  std::vector<Spline> spline_data{spline};
  std::vector<QuantizedSpline> quantized_splines;
  std::vector<Spline::Point> starting_points;
  for (const Spline& spline : spline_data) {
    quantized_splines.emplace_back(spline, kQuantizationAdjustment, kYToX,
                                   kYToB);
    starting_points.push_back(spline.control_points.front());
  }
  Splines splines(kQuantizationAdjustment, std::move(quantized_splines),
                  std::move(starting_points));

  Image3F image(320, 320);
  ZeroFillImage(&image);
  EXPECT_FALSE(
      splines.InitializeDrawCache(image.xsize(), image.ysize(), *cmap));
}

TEST(SplinesTest, Drawing) {
  CodecInOut io_expected;
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/splines.pfm");
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io_expected,
                           /*pool=*/nullptr));

  std::vector<Spline::Point> control_points{{9, 54},  {118, 159}, {97, 3},
                                            {10, 40}, {150, 25},  {120, 300}};
  // Use values that survive quant/decorellation roundtrip.
  const Spline spline{
      control_points,
      /*color_dct=*/
      {{0.4989345073699951171875000f, 0.4997999966144561767578125f},
       {0.4772970676422119140625000f, 0.f, 0.5250000357627868652343750f},
       {-0.0176776945590972900390625f, 0.4900000095367431640625000f,
        0.5250000357627868652343750f}},
      /*sigma_dct=*/
      {0.9427147507667541503906250f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f,
       0.6665999889373779296875000f}};
  std::vector<Spline> spline_data = {spline};
  std::vector<QuantizedSpline> quantized_splines;
  std::vector<Spline::Point> starting_points;
  for (const Spline& spline : spline_data) {
    quantized_splines.emplace_back(spline, kQuantizationAdjustment, kYToX,
                                   kYToB);
    starting_points.push_back(spline.control_points.front());
  }
  Splines splines(kQuantizationAdjustment, std::move(quantized_splines),
                  std::move(starting_points));

  Image3F image(320, 320);
  ZeroFillImage(&image);
  ASSERT_TRUE(splines.InitializeDrawCache(image.xsize(), image.ysize(), *cmap));
  splines.AddTo(&image, Rect(image), Rect(image));

  CodecInOut io_actual;
  Image3F image2(320, 320);
  CopyImageTo(image, &image2);
  io_actual.SetFromImage(std::move(image2), ColorEncoding::SRGB());
  ASSERT_TRUE(io_actual.frames[0].TransformTo(io_expected.Main().c_current(),
                                              GetJxlCms()));

  JXL_ASSERT_OK(VerifyRelativeError(
      *io_expected.Main().color(), *io_actual.Main().color(), 1e-2f, 1e-1f, _));
}

TEST(SplinesTest, ClearedEveryFrame) {
  CodecInOut io_expected;
  const PaddedBytes bytes_expected =
      jxl::test::ReadTestData("jxl/spline_on_first_frame.png");
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(bytes_expected), &io_expected,
                           /*pool=*/nullptr));
  CodecInOut io_actual;
  const PaddedBytes bytes_actual =
      jxl::test::ReadTestData("jxl/spline_on_first_frame.jxl");
  ASSERT_TRUE(
      test::DecodeFile({}, Span<const uint8_t>(bytes_actual), &io_actual));

  ASSERT_TRUE(
      io_actual.frames[0].TransformTo(ColorEncoding::SRGB(), GetJxlCms()));
  for (size_t c = 0; c < 3; ++c) {
    for (size_t y = 0; y < io_actual.ysize(); ++y) {
      float* const JXL_RESTRICT row = io_actual.Main().color()->PlaneRow(c, y);
      for (size_t x = 0; x < io_actual.xsize(); ++x) {
        row[x] = Clamp1(row[x], 0.f, 1.f);
      }
    }
  }
  JXL_ASSERT_OK(VerifyRelativeError(
      *io_expected.Main().color(), *io_actual.Main().color(), 1e-2f, 1e-1f, _));
}

}  // namespace jxl
