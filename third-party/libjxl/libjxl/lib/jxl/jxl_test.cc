// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/dec/jxl.h"

#include <stdint.h>
#include <stdio.h>

#include <array>
#include <future>
#include <string>
#include <tuple>
#include <utility>
#include <vector>

#include "lib/extras/codec.h"
#include "lib/extras/dec/decode.h"
#include "lib/extras/enc/encode.h"
#include "lib/extras/packed_image.h"
#include "lib/jxl/alpha.h"
#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/override.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/color_management.h"
#include "lib/jxl/enc_butteraugli_comparator.h"
#include "lib/jxl/enc_cache.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_file.h"
#include "lib/jxl/enc_params.h"
#include "lib/jxl/fake_parallel_runner_testonly.h"
#include "lib/jxl/image.h"
#include "lib/jxl/image_bundle.h"
#include "lib/jxl/image_ops.h"
#include "lib/jxl/image_test_utils.h"
#include "lib/jxl/jpeg/dec_jpeg_data.h"
#include "lib/jxl/jpeg/dec_jpeg_data_writer.h"
#include "lib/jxl/jpeg/enc_jpeg_data.h"
#include "lib/jxl/jpeg/jpeg_data.h"
#include "lib/jxl/modular/options.h"
#include "lib/jxl/test_image.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"
#include "tools/box/box.h"

namespace jxl {

struct AuxOut;

namespace {
using extras::JXLCompressParams;
using extras::JXLDecompressParams;
using extras::PackedPixelFile;
using test::ButteraugliDistance;
using test::ComputeDistance2;
using test::Roundtrip;
using test::TestImage;
using test::ThreadPoolForTests;

#define JXL_TEST_NL 0  // Disabled in code

TEST(JxlTest, RoundtripSinglePixel) {
  TestImage t;
  t.SetDimensions(1, 1).AddFrame().ZeroFill();
  PackedPixelFile ppf_out;
  EXPECT_EQ(Roundtrip(t.ppf(), {}, {}, nullptr, &ppf_out), 55);
}

TEST(JxlTest, RoundtripSinglePixelWithAlpha) {
  TestImage t;
  t.SetDimensions(1, 1).SetChannels(4).AddFrame().ZeroFill();
  PackedPixelFile ppf_out;
  EXPECT_EQ(Roundtrip(t.ppf(), {}, {}, nullptr, &ppf_out), 59);
}

// Changing serialized signature causes Decode to fail.
#ifndef JXL_CRASH_ON_ERROR
TEST(JxlTest, RoundtripMarker) {
  TestImage t;
  t.SetDimensions(1, 1).AddFrame().ZeroFill();
  for (size_t i = 0; i < 2; ++i) {
    std::vector<uint8_t> compressed;
    EXPECT_TRUE(extras::EncodeImageJXL({}, t.ppf(), /*jpeg_bytes=*/nullptr,
                                       &compressed));
    compressed[i] ^= 0xFF;
    PackedPixelFile ppf_out;
    EXPECT_FALSE(extras::DecodeImageJXL(compressed.data(), compressed.size(),
                                        {}, /*decodec_bytes=*/nullptr,
                                        &ppf_out));
  }
}
#endif

TEST(JxlTest, RoundtripTinyFast) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata().SetDimensions(32, 32);

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 7);
  cparams.distance = 4.0f;

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 181, 15);
}

TEST(JxlTest, RoundtripSmallD1) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  size_t xsize = t.ppf().info.xsize / 8;
  size_t ysize = t.ppf().info.ysize / 8;
  t.SetDimensions(xsize, ysize);

  {
    PackedPixelFile ppf_out;
    EXPECT_NEAR(Roundtrip(t.ppf(), {}, {}, pool, &ppf_out), 816, 40);
    EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(0.888));
  }

  // With a lower intensity target than the default, the bitrate should be
  // smaller.
  t.ppf().info.intensity_target = 100.0f;

  {
    PackedPixelFile ppf_out;
    EXPECT_NEAR(Roundtrip(t.ppf(), {}, {}, pool, &ppf_out), 659, 20);
    EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(1.3));
    EXPECT_EQ(ppf_out.info.intensity_target, t.ppf().info.intensity_target);
  }
}
TEST(JxlTest, RoundtripResample2) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_RESAMPLING, 2);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 3);  // kFalcon

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 18500, 200);
  EXPECT_THAT(ComputeDistance2(t.ppf(), ppf_out), IsSlightlyBelow(90));
}

TEST(JxlTest, RoundtripResample2Slow) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_RESAMPLING, 2);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 9);  // kTortoise
  cparams.distance = 10.0;

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 3888, 200);
  EXPECT_THAT(ComputeDistance2(t.ppf(), ppf_out), IsSlightlyBelow(250));
}

TEST(JxlTest, RoundtripResample2MT) {
  ThreadPoolForTests pool(4);
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/flower/flower.png");
  // image has to be large enough to have multiple groups after downsampling
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_RESAMPLING, 2);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 3);  // kFalcon

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out), 223310, 2000);
  EXPECT_THAT(ComputeDistance2(t.ppf(), ppf_out), IsSlightlyBelow(340));
}

// Roundtrip the image using a parallel runner that executes single-threaded but
// in random order.
TEST(JxlTest, RoundtripOutOfOrderProcessing) {
  FakeParallelRunner fake_pool(/*order_seed=*/123, /*num_threads=*/8);
  ThreadPool pool(&JxlFakeParallelRunner, &fake_pool);
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/flower/flower.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  // Image size is selected so that the block border needed is larger than the
  // amount of pixels available on the next block.
  t.SetDimensions(513, 515);

  JXLCompressParams cparams;
  // Force epf so we end up needing a lot of border.
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EPF, 3);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out), 22999, 400);
  EXPECT_LE(ButteraugliDistance(t.ppf(), ppf_out), 1.35);
}

TEST(JxlTest, RoundtripOutOfOrderProcessingBorder) {
  FakeParallelRunner fake_pool(/*order_seed=*/47, /*num_threads=*/8);
  ThreadPool pool(&JxlFakeParallelRunner, &fake_pool);
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/flower/flower.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  // Image size is selected so that the block border needed is larger than the
  // amount of pixels available on the next block.
  t.SetDimensions(513, 515);

  JXLCompressParams cparams;
  // Force epf so we end up needing a lot of border.
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EPF, 3);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_RESAMPLING, 2);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out), 11015, 200);
  EXPECT_LE(ButteraugliDistance(t.ppf(), ppf_out), 2.9);
}

TEST(JxlTest, RoundtripResample4) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_RESAMPLING, 4);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 5758, 100);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(22));
}

TEST(JxlTest, RoundtripResample8) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_RESAMPLING, 8);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 2036, 50);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(50));
}

TEST(JxlTest, RoundtripUnalignedD2) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  size_t xsize = t.ppf().info.xsize / 12;
  size_t ysize = t.ppf().info.ysize / 7;
  t.SetDimensions(xsize, ysize);

  JXLCompressParams cparams;
  cparams.distance = 2.0;

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 506, 30);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(1.72));
}

TEST(JxlTest, RoundtripMultiGroup) {
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/flower/flower.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata().SetDimensions(600, 1024);

  auto test = [&](jxl::SpeedTier speed_tier, float target_distance,
                  size_t expected_size, float expected_distance) {
    ThreadPoolForTests pool(4);
    JXLCompressParams cparams;
    int64_t effort = 10 - static_cast<int>(speed_tier);
    cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, effort);
    cparams.distance = target_distance;

    PackedPixelFile ppf_out;
    EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out), expected_size,
                700);
    EXPECT_THAT(ComputeDistance2(t.ppf(), ppf_out),
                IsSlightlyBelow(expected_distance));
  };

  auto run_kitten = std::async(std::launch::async, test, SpeedTier::kKitten,
                               1.0f, 55602u, 11.7);
  auto run_wombat = std::async(std::launch::async, test, SpeedTier::kWombat,
                               2.0f, 33624u, 20.0);
}

TEST(JxlTest, RoundtripRGBToGrayscale) {
  ThreadPoolForTests pool(4);
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/flower/flower.png");
  CodecInOut io;
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io, &pool));
  io.ShrinkTo(600, 1024);

  CompressParams cparams;
  cparams.butteraugli_distance = 1.0f;
  cparams.speed_tier = SpeedTier::kFalcon;

  JXLDecompressParams dparams;
  dparams.color_space = "Gra_D65_Rel_SRG";

  CodecInOut io2;
  EXPECT_FALSE(io.Main().IsGray());
  size_t compressed_size;
  JXL_EXPECT_OK(
      Roundtrip(&io, cparams, dparams, &io2, _, &compressed_size, &pool));
  EXPECT_LE(compressed_size, 65000u);
  EXPECT_TRUE(io2.Main().IsGray());

  // Convert original to grayscale here, because TransformTo refuses to
  // convert between grayscale and RGB.
  ColorEncoding srgb_lin = ColorEncoding::LinearSRGB(/*is_gray=*/false);
  ASSERT_TRUE(io.frames[0].TransformTo(srgb_lin, GetJxlCms()));
  Image3F* color = io.Main().color();
  for (size_t y = 0; y < color->ysize(); ++y) {
    float* row_r = color->PlaneRow(0, y);
    float* row_g = color->PlaneRow(1, y);
    float* row_b = color->PlaneRow(2, y);
    for (size_t x = 0; x < color->xsize(); ++x) {
      float luma = 0.2126 * row_r[x] + 0.7152 * row_g[x] + 0.0722 * row_b[x];
      row_r[x] = row_g[x] = row_b[x] = luma;
    }
  }
  ColorEncoding srgb_gamma = ColorEncoding::SRGB(/*is_gray=*/false);
  ASSERT_TRUE(io.frames[0].TransformTo(srgb_gamma, GetJxlCms()));
  io.metadata.m.color_encoding = io2.Main().c_current();
  io.Main().OverrideProfile(io2.Main().c_current());
  EXPECT_THAT(ButteraugliDistance(io.frames, io2.frames, ButteraugliParams(),
                                  GetJxlCms(),
                                  /*distmap=*/nullptr, &pool),
              IsSlightlyBelow(1.36));
}

TEST(JxlTest, RoundtripLargeFast) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/flower/flower.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 7);  // kSquirrel

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out), 445555, 5000);
  EXPECT_THAT(ComputeDistance2(t.ppf(), ppf_out), IsSlightlyBelow(100));
}

TEST(JxlTest, RoundtripDotsForceEpf) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/cvo9xd_keong_macan_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 7);  // kSquirrel
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EPF, 2);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_DOTS, 1);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out), 41777, 300);
  EXPECT_THAT(ComputeDistance2(t.ppf(), ppf_out), IsSlightlyBelow(18));
}

// Checks for differing size/distance in two consecutive runs of distance 2,
// which involves additional processing including adaptive reconstruction.
// Failing this may be a sign of race conditions or invalid memory accesses.
TEST(JxlTest, RoundtripD2Consistent) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/flower/flower.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 7);  // kSquirrel
  cparams.distance = 2.0;

  // Try each xsize mod kBlockDim to verify right border handling.
  for (size_t xsize = 48; xsize > 40; --xsize) {
    t.SetDimensions(xsize, 15);

    PackedPixelFile ppf2;
    const size_t size2 = Roundtrip(t.ppf(), cparams, {}, &pool, &ppf2);

    PackedPixelFile ppf3;
    const size_t size3 = Roundtrip(t.ppf(), cparams, {}, &pool, &ppf3);

    // Exact same compressed size.
    EXPECT_EQ(size2, size3);

    // Exact same distance.
    const float dist2 = ComputeDistance2(t.ppf(), ppf2);
    const float dist3 = ComputeDistance2(t.ppf(), ppf3);
    EXPECT_EQ(dist2, dist3);
  }
}

// Same as above, but for full image, testing multiple groups.
TEST(JxlTest, RoundtripLargeConsistent) {
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/flower/flower.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 7);  // kSquirrel
  cparams.distance = 2.0;

  auto roundtrip_and_compare = [&]() {
    ThreadPoolForTests pool(8);
    PackedPixelFile ppf2;
    size_t size = Roundtrip(t.ppf(), cparams, {}, &pool, &ppf2);
    double dist = ComputeDistance2(t.ppf(), ppf2);
    return std::tuple<size_t, double>(size, dist);
  };

  // Try each xsize mod kBlockDim to verify right border handling.
  auto future2 = std::async(std::launch::async, roundtrip_and_compare);
  auto future3 = std::async(std::launch::async, roundtrip_and_compare);

  const auto result2 = future2.get();
  const auto result3 = future3.get();

  // Exact same compressed size.
  EXPECT_EQ(std::get<0>(result2), std::get<0>(result3));

  // Exact same distance.
  EXPECT_EQ(std::get<1>(result2), std::get<1>(result3));
}

TEST(JxlTest, RoundtripSmallNL) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  size_t xsize = t.ppf().info.xsize / 8;
  size_t ysize = t.ppf().info.ysize / 8;
  t.SetDimensions(xsize, ysize);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), {}, {}, pool, &ppf_out), 801, 45);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(1.1));
}

TEST(JxlTest, RoundtripNoGaborishNoAR) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EPF, 0);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_GABORISH, 0);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 38900, 200);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(1.8));
}

TEST(JxlTest, RoundtripSmallNoGaborish) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  size_t xsize = t.ppf().info.xsize / 8;
  size_t ysize = t.ppf().info.ysize / 8;
  t.SetDimensions(xsize, ysize);

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_GABORISH, 0);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 811, 20);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(1.1));
}

TEST(JxlTest, RoundtripSmallPatchesAlpha) {
  ThreadPool* pool = nullptr;
  TestImage t;
  t.SetDimensions(256, 256).SetChannels(4);
  t.SetColorEncoding("RGB_D65_SRG_Rel_Lin");
  TestImage::Frame frame = t.AddFrame();
  frame.ZeroFill();
  // This pattern should be picked up by the patch detection heuristics.
  for (size_t y = 0; y < t.ppf().info.ysize; ++y) {
    for (size_t x = 0; x < t.ppf().info.xsize; ++x) {
      if (x % 4 == 0 && (y / 32) % 4 == 0) {
        frame.SetValue(y, x, 1, 127.0f / 255.0f);
      }
      frame.SetValue(y, x, 3, 1.0f);
    }
  }

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 7);  // kSquirrel
  cparams.distance = 0.1f;

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 597, 100);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(0.018f));
}

TEST(JxlTest, RoundtripSmallPatches) {
  ThreadPool* pool = nullptr;
  TestImage t;
  t.SetDimensions(256, 256);
  t.SetColorEncoding("RGB_D65_SRG_Rel_Lin");
  TestImage::Frame frame = t.AddFrame();
  frame.ZeroFill();
  // This pattern should be picked up by the patch detection heuristics.
  for (size_t y = 0; y < t.ppf().info.ysize; ++y) {
    for (size_t x = 0; x < t.ppf().info.xsize; ++x) {
      if (x % 4 == 0 && (y / 32) % 4 == 0) {
        frame.SetValue(y, x, 1, 127.0f / 255.0f);
      }
    }
  }

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 7);  // kSquirrel
  cparams.distance = 0.1f;

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 486, 100);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(0.018f));
}

// TODO(szabadka) Add encoder and decoder API functions that accept frame
// buffers in arbitrary unsigned and floating point formats, and then roundtrip
// test the lossless codepath to make sure the exact binary representations
// are preserved.
#if 0
TEST(JxlTest, RoundtripImageBundleOriginalBits) {
  // Image does not matter, only io.metadata.m and io2.metadata.m are tested.
  Image3F image(1, 1);
  ZeroFillImage(&image);
  CodecInOut io;
  io.metadata.m.color_encoding = ColorEncoding::LinearSRGB();
  io.SetFromImage(std::move(image), ColorEncoding::LinearSRGB());

  CompressParams cparams;

  // Test unsigned integers from 1 to 32 bits
  for (uint32_t bit_depth = 1; bit_depth <= 32; bit_depth++) {
    if (bit_depth == 32) {
      // TODO(lode): allow testing 32, however the code below ends up in
      // enc_modular which does not support 32. We only want to test the header
      // encoding though, so try without modular.
      break;
    }

    io.metadata.m.SetUintSamples(bit_depth);
    CodecInOut io2;
    JXL_EXPECT_OK(Roundtrip(&io, cparams, {}, &io2, _));

    EXPECT_EQ(bit_depth, io2.metadata.m.bit_depth.bits_per_sample);
    EXPECT_FALSE(io2.metadata.m.bit_depth.floating_point_sample);
    EXPECT_EQ(0u, io2.metadata.m.bit_depth.exponent_bits_per_sample);
    EXPECT_EQ(0u, io2.metadata.m.GetAlphaBits());
  }

  // Test various existing and non-existing floating point formats
  for (uint32_t bit_depth = 8; bit_depth <= 32; bit_depth++) {
    if (bit_depth != 32) {
      // TODO: test other float types once they work
      break;
    }

    uint32_t exponent_bit_depth;
    if (bit_depth < 10) {
      exponent_bit_depth = 2;
    } else if (bit_depth < 12) {
      exponent_bit_depth = 3;
    } else if (bit_depth < 16) {
      exponent_bit_depth = 4;
    } else if (bit_depth < 20) {
      exponent_bit_depth = 5;
    } else if (bit_depth < 24) {
      exponent_bit_depth = 6;
    } else if (bit_depth < 28) {
      exponent_bit_depth = 7;
    } else {
      exponent_bit_depth = 8;
    }

    io.metadata.m.bit_depth.bits_per_sample = bit_depth;
    io.metadata.m.bit_depth.floating_point_sample = true;
    io.metadata.m.bit_depth.exponent_bits_per_sample = exponent_bit_depth;

    CodecInOut io2;
    JXL_EXPECT_OK(Roundtrip(&io, cparams, {}, &io2));

    EXPECT_EQ(bit_depth, io2.metadata.m.bit_depth.bits_per_sample);
    EXPECT_TRUE(io2.metadata.m.bit_depth.floating_point_sample);
    EXPECT_EQ(exponent_bit_depth,
              io2.metadata.m.bit_depth.exponent_bits_per_sample);
    EXPECT_EQ(0u, io2.metadata.m.GetAlphaBits());
  }
}
#endif

TEST(JxlTest, RoundtripGrayscale) {
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/cvo9xd_keong_macan_grayscale.png");
  CodecInOut io;
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io));
  ASSERT_NE(io.xsize(), 0u);
  io.ShrinkTo(128, 128);
  EXPECT_TRUE(io.Main().IsGray());
  EXPECT_EQ(8u, io.metadata.m.bit_depth.bits_per_sample);
  EXPECT_FALSE(io.metadata.m.bit_depth.floating_point_sample);
  EXPECT_EQ(0u, io.metadata.m.bit_depth.exponent_bits_per_sample);
  EXPECT_TRUE(io.metadata.m.color_encoding.tf.IsSRGB());

  PassesEncoderState enc_state;
  AuxOut* aux_out = nullptr;

  {
    CompressParams cparams;
    cparams.butteraugli_distance = 1.0;

    PaddedBytes compressed;
    EXPECT_TRUE(EncodeFile(cparams, &io, &enc_state, &compressed, GetJxlCms(),
                           aux_out));
    CodecInOut io2;
    EXPECT_TRUE(test::DecodeFile({}, Span<const uint8_t>(compressed), &io2));
    EXPECT_TRUE(io2.Main().IsGray());

    EXPECT_LE(compressed.size(), 7000u);
    EXPECT_THAT(ButteraugliDistance(io.frames, io2.frames, ButteraugliParams(),
                                    GetJxlCms(),
                                    /*distmap=*/nullptr),
                IsSlightlyBelow(1.6));
  }

  // Test with larger butteraugli distance and other settings enabled so
  // different jxl codepaths trigger.
  {
    CompressParams cparams;
    cparams.butteraugli_distance = 8.0;

    PaddedBytes compressed;
    EXPECT_TRUE(EncodeFile(cparams, &io, &enc_state, &compressed, GetJxlCms(),
                           aux_out));
    CodecInOut io2;
    EXPECT_TRUE(test::DecodeFile({}, Span<const uint8_t>(compressed), &io2));
    EXPECT_TRUE(io2.Main().IsGray());

    EXPECT_LE(compressed.size(), 1300u);
    EXPECT_THAT(ButteraugliDistance(io.frames, io2.frames, ButteraugliParams(),
                                    GetJxlCms(),
                                    /*distmap=*/nullptr),
                IsSlightlyBelow(6.0));
  }

  {
    CompressParams cparams;
    cparams.butteraugli_distance = 1.0;

    PaddedBytes compressed;
    EXPECT_TRUE(EncodeFile(cparams, &io, &enc_state, &compressed, GetJxlCms(),
                           aux_out));

    CodecInOut io2;
    JXLDecompressParams dparams;
    dparams.color_space = "RGB_D65_SRG_Rel_SRG";
    EXPECT_TRUE(
        test::DecodeFile(dparams, Span<const uint8_t>(compressed), &io2));
    EXPECT_FALSE(io2.Main().IsGray());

    EXPECT_LE(compressed.size(), 7000u);
    EXPECT_THAT(ButteraugliDistance(io.frames, io2.frames, ButteraugliParams(),
                                    GetJxlCms(),
                                    /*distmap=*/nullptr),
                IsSlightlyBelow(1.6));
  }
}

TEST(JxlTest, RoundtripAlpha) {
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/tmshre_riaphotographs_alpha.png");
  CodecInOut io;
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io));

  ASSERT_NE(io.xsize(), 0u);
  ASSERT_TRUE(io.metadata.m.HasAlpha());
  ASSERT_TRUE(io.Main().HasAlpha());
  io.ShrinkTo(300, 300);

  CompressParams cparams;
  cparams.butteraugli_distance = 1.0;

  EXPECT_EQ(8u, io.metadata.m.bit_depth.bits_per_sample);
  EXPECT_FALSE(io.metadata.m.bit_depth.floating_point_sample);
  EXPECT_EQ(0u, io.metadata.m.bit_depth.exponent_bits_per_sample);
  EXPECT_TRUE(io.metadata.m.color_encoding.tf.IsSRGB());
  PassesEncoderState enc_state;
  AuxOut* aux_out = nullptr;
  PaddedBytes compressed;
  EXPECT_TRUE(
      EncodeFile(cparams, &io, &enc_state, &compressed, GetJxlCms(), aux_out));

  EXPECT_LE(compressed.size(), 10077u);

  for (bool use_image_callback : {false, true}) {
    for (bool unpremul_alpha : {false, true}) {
      CodecInOut io2;
      JXLDecompressParams dparams;
      dparams.use_image_callback = use_image_callback;
      dparams.unpremultiply_alpha = unpremul_alpha;
      EXPECT_TRUE(
          test::DecodeFile(dparams, Span<const uint8_t>(compressed), &io2));
      EXPECT_THAT(ButteraugliDistance(io.frames, io2.frames,
                                      ButteraugliParams(), GetJxlCms(),
                                      /*distmap=*/nullptr),
                  IsSlightlyBelow(1.15));
    }
  }
}

namespace {
// Performs "PremultiplyAlpha" for each ImageBundle (preview/frames).
bool PremultiplyAlpha(CodecInOut& io) {
  const auto doPremultiplyAlpha = [](ImageBundle& bundle) {
    if (!bundle.HasAlpha()) return;
    if (!bundle.HasColor()) return;
    auto* color = bundle.color();
    const auto* alpha = bundle.alpha();
    JXL_CHECK(color->ysize() == alpha->ysize());
    JXL_CHECK(color->xsize() == alpha->xsize());
    for (size_t y = 0; y < color->ysize(); y++) {
      ::jxl::PremultiplyAlpha(color->PlaneRow(0, y), color->PlaneRow(1, y),
                              color->PlaneRow(2, y), alpha->Row(y),
                              color->xsize());
    }
  };
  ExtraChannelInfo* eci = io.metadata.m.Find(ExtraChannel::kAlpha);
  if (eci == nullptr || eci->alpha_associated) return false;
  if (io.metadata.m.have_preview) {
    doPremultiplyAlpha(io.preview_frame);
  }
  for (ImageBundle& ib : io.frames) {
    doPremultiplyAlpha(ib);
  }
  eci->alpha_associated = true;
  return true;
}

bool UnpremultiplyAlpha(CodecInOut& io) {
  const auto doUnpremultiplyAlpha = [](ImageBundle& bundle) {
    if (!bundle.HasAlpha()) return;
    if (!bundle.HasColor()) return;
    auto* color = bundle.color();
    const auto* alpha = bundle.alpha();
    JXL_CHECK(color->ysize() == alpha->ysize());
    JXL_CHECK(color->xsize() == alpha->xsize());
    for (size_t y = 0; y < color->ysize(); y++) {
      ::jxl::UnpremultiplyAlpha(color->PlaneRow(0, y), color->PlaneRow(1, y),
                                color->PlaneRow(2, y), alpha->Row(y),
                                color->xsize());
    }
  };
  ExtraChannelInfo* eci = io.metadata.m.Find(ExtraChannel::kAlpha);
  if (eci == nullptr || !eci->alpha_associated) return false;
  if (io.metadata.m.have_preview) {
    doUnpremultiplyAlpha(io.preview_frame);
  }
  for (ImageBundle& ib : io.frames) {
    doUnpremultiplyAlpha(ib);
  }
  eci->alpha_associated = false;
  return true;
}
}  // namespace

TEST(JxlTest, RoundtripAlphaPremultiplied) {
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/tmshre_riaphotographs_alpha.png");
  CodecInOut io, io_nopremul;
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io));
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io_nopremul));

  ASSERT_NE(io.xsize(), 0u);
  ASSERT_TRUE(io.metadata.m.HasAlpha());
  ASSERT_TRUE(io.Main().HasAlpha());
  io.ShrinkTo(300, 300);
  io_nopremul.ShrinkTo(300, 300);

  CompressParams cparams;
  cparams.butteraugli_distance = 1.0;
  cparams.SetCms(GetJxlCms());

  EXPECT_FALSE(io.Main().AlphaIsPremultiplied());
  EXPECT_TRUE(PremultiplyAlpha(io));
  EXPECT_TRUE(io.Main().AlphaIsPremultiplied());

  EXPECT_FALSE(io_nopremul.Main().AlphaIsPremultiplied());

  PassesEncoderState enc_state;
  AuxOut* aux_out = nullptr;
  PaddedBytes compressed;
  EXPECT_TRUE(
      EncodeFile(cparams, &io, &enc_state, &compressed, GetJxlCms(), aux_out));
  EXPECT_LE(compressed.size(), 10000u);

  for (bool use_image_callback : {false, true}) {
    for (bool unpremul_alpha : {false, true}) {
      for (bool use_uint8 : {false, true}) {
        printf(
            "Testing premultiplied alpha using %s %s requesting "
            "%spremultiplied output.\n",
            use_uint8 ? "uint8" : "float",
            use_image_callback ? "image callback" : "image_buffer",
            unpremul_alpha ? "un" : "");
        CodecInOut io2;
        JXLDecompressParams dparams;
        dparams.use_image_callback = use_image_callback;
        dparams.unpremultiply_alpha = unpremul_alpha;
        if (use_uint8) {
          dparams.accepted_formats = {
              {4, JXL_TYPE_UINT8, JXL_LITTLE_ENDIAN, 0}};
        }
        EXPECT_TRUE(
            test::DecodeFile(dparams, Span<const uint8_t>(compressed), &io2));

        EXPECT_EQ(unpremul_alpha, !io2.Main().AlphaIsPremultiplied());
        if (!unpremul_alpha) {
          EXPECT_THAT(ButteraugliDistance(io.frames, io2.frames,
                                          ButteraugliParams(), GetJxlCms(),
                                          /*distmap=*/nullptr),
                      IsSlightlyBelow(1.111));
          EXPECT_TRUE(UnpremultiplyAlpha(io2));
          EXPECT_FALSE(io2.Main().AlphaIsPremultiplied());
        }
        EXPECT_THAT(ButteraugliDistance(io_nopremul.frames, io2.frames,
                                        ButteraugliParams(), GetJxlCms(),
                                        /*distmap=*/nullptr),
                    IsSlightlyBelow(1.55));
      }
    }
  }
}

TEST(JxlTest, RoundtripAlphaResampling) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/tmshre_riaphotographs_alpha.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  ASSERT_NE(t.ppf().info.xsize, 0);
  ASSERT_TRUE(t.ppf().info.alpha_bits > 0);

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 5);  // kHare
  cparams.AddOption(JXL_ENC_FRAME_SETTING_RESAMPLING, 2);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EXTRA_CHANNEL_RESAMPLING, 2);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 13155, 130);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(5.2));
}

TEST(JxlTest, RoundtripAlphaResamplingOnlyAlpha) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/tmshre_riaphotographs_alpha.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  ASSERT_NE(t.ppf().info.xsize, 0);
  ASSERT_TRUE(t.ppf().info.alpha_bits > 0);

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 3);  // kFalcon
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EXTRA_CHANNEL_RESAMPLING, 2);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 33571, 400);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(1.49));
}

TEST(JxlTest, RoundtripAlphaNonMultipleOf8) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/tmshre_riaphotographs_alpha.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata().SetDimensions(12, 12);
  ASSERT_NE(t.ppf().info.xsize, 0);
  ASSERT_TRUE(t.ppf().info.alpha_bits > 0);
  EXPECT_EQ(t.ppf().frames[0].color.format.data_type, JXL_TYPE_UINT8);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), {}, {}, pool, &ppf_out), 107, 10);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(0.95));
}

TEST(JxlTest, RoundtripAlpha16) {
  ThreadPoolForTests pool(4);
  // The image is wider than 512 pixels to ensure multiple groups are tested.
  size_t xsize = 1200, ysize = 160;
  TestImage t;
  t.SetDimensions(xsize, ysize).SetChannels(4).SetAllBitDepths(16);
  TestImage::Frame frame = t.AddFrame();
  // Generate 16-bit pattern that uses various colors and alpha values.
  const float mul = 1.0f / 65535;
  for (size_t y = 0; y < ysize; y++) {
    for (size_t x = 0; x < xsize; x++) {
      uint16_t r = y * 65535 / ysize;
      uint16_t g = x * 65535 / xsize;
      uint16_t b = (y + x) * 65535 / (xsize + ysize);
      frame.SetValue(y, x, 0, r * mul);
      frame.SetValue(y, x, 1, g * mul);
      frame.SetValue(y, x, 2, b * mul);
      frame.SetValue(y, x, 3, g * mul);
    }
  }

  ASSERT_NE(t.ppf().info.xsize, 0);
  ASSERT_EQ(t.ppf().info.alpha_bits, 16);

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 6);  // kWombat
  cparams.distance = 0.5;

  PackedPixelFile ppf_out;
  // TODO(szabadka) Investigate big size difference on i686
  // This still keeps happening (2023-04-18).
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out), 3466, 120);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(0.65));
}

namespace {
JXLCompressParams CompressParamsForLossless() {
  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_MODULAR, 1);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_COLOR_TRANSFORM, 1);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_MODULAR_PREDICTOR, 6);  // Weighted
  cparams.distance = 0;
  return cparams;
}
}  // namespace

TEST(JxlTest, JXL_SLOW_TEST(RoundtripLossless8)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/tmshre_riaphotographs_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams = CompressParamsForLossless();

  PackedPixelFile ppf_out;
  EXPECT_EQ(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out), 223058);
  EXPECT_EQ(ComputeDistance2(t.ppf(), ppf_out), 0.0);
}

TEST(JxlTest, JXL_SLOW_TEST(RoundtripLossless8ThunderGradient)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/tmshre_riaphotographs_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams = CompressParamsForLossless();
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 2);             // kThunder
  cparams.AddOption(JXL_ENC_FRAME_SETTING_MODULAR_PREDICTOR, 5);  // Gradient

  PackedPixelFile ppf_out;
  EXPECT_EQ(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out), 261684);
  EXPECT_EQ(ComputeDistance2(t.ppf(), ppf_out), 0.0);
}

TEST(JxlTest, JXL_SLOW_TEST(RoundtripLossless8LightningGradient)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/tmshre_riaphotographs_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams = CompressParamsForLossless();
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 1);  // kLightning

  PackedPixelFile ppf_out;
  // Lax comparison because different SIMD will cause different compression.
  EXPECT_THAT(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out),
              IsSlightlyBelow(286848u));
  EXPECT_EQ(ComputeDistance2(t.ppf(), ppf_out), 0.0);
}

TEST(JxlTest, JXL_SLOW_TEST(RoundtripLossless8Falcon)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/tmshre_riaphotographs_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();

  JXLCompressParams cparams = CompressParamsForLossless();
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 3);  // kFalcon

  PackedPixelFile ppf_out;
  EXPECT_EQ(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out), 230766);
  EXPECT_EQ(ComputeDistance2(t.ppf(), ppf_out), 0.0);
}

TEST(JxlTest, RoundtripLossless8Alpha) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/tmshre_riaphotographs_alpha.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  ASSERT_EQ(t.ppf().info.alpha_bits, 8);
  EXPECT_EQ(t.ppf().frames[0].color.format.data_type, JXL_TYPE_UINT8);

  JXLCompressParams cparams = CompressParamsForLossless();

  JXLDecompressParams dparams;
  dparams.accepted_formats.push_back(t.ppf().frames[0].color.format);

  PackedPixelFile ppf_out;
  EXPECT_EQ(Roundtrip(t.ppf(), cparams, dparams, pool, &ppf_out), 251470);
  EXPECT_EQ(ComputeDistance2(t.ppf(), ppf_out), 0.0);
  EXPECT_EQ(ppf_out.info.alpha_bits, 8);
  EXPECT_TRUE(test::SameAlpha(t.ppf(), ppf_out));
}

TEST(JxlTest, RoundtripLossless16Alpha) {
  ThreadPool* pool = nullptr;
  size_t xsize = 1200, ysize = 160;
  TestImage t;
  t.SetDimensions(xsize, ysize).SetChannels(4).SetAllBitDepths(16);
  TestImage::Frame frame = t.AddFrame();
  // Generate 16-bit pattern that uses various colors and alpha values.
  const float mul = 1.0f / 65535;
  for (size_t y = 0; y < ysize; y++) {
    for (size_t x = 0; x < xsize; x++) {
      uint16_t r = y * 65535 / ysize;
      uint16_t g = x * 65535 / xsize + 37;
      uint16_t b = (y + x) * 65535 / (xsize + ysize);
      frame.SetValue(y, x, 0, r * mul);
      frame.SetValue(y, x, 1, g * mul);
      frame.SetValue(y, x, 2, b * mul);
      frame.SetValue(y, x, 3, g * mul);
    }
  }
  ASSERT_EQ(t.ppf().info.bits_per_sample, 16);
  ASSERT_EQ(t.ppf().info.alpha_bits, 16);

  JXLCompressParams cparams = CompressParamsForLossless();

  JXLDecompressParams dparams;
  dparams.accepted_formats.push_back(t.ppf().frames[0].color.format);

  PackedPixelFile ppf_out;
  // TODO(szabadka) Investigate big size difference on i686
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, dparams, pool, &ppf_out), 4884, 100);
  EXPECT_EQ(ComputeDistance2(t.ppf(), ppf_out), 0.0);
  EXPECT_EQ(ppf_out.info.alpha_bits, 16);
  EXPECT_TRUE(test::SameAlpha(t.ppf(), ppf_out));
}

TEST(JxlTest, RoundtripLossless16AlphaNotMisdetectedAs8Bit) {
  ThreadPool* pool = nullptr;
  size_t xsize = 128, ysize = 128;
  TestImage t;
  t.SetDimensions(xsize, ysize).SetChannels(4).SetAllBitDepths(16);
  TestImage::Frame frame = t.AddFrame();
  // All 16-bit values, both color and alpha, of this image are below 64.
  // This allows testing if a code path wrongly concludes it's an 8-bit instead
  // of 16-bit image (or even 6-bit).
  const float mul = 1.0f / 65535;
  for (size_t y = 0; y < ysize; y++) {
    for (size_t x = 0; x < xsize; x++) {
      uint16_t r = y * 64 / ysize;
      uint16_t g = x * 64 / xsize + 37;
      uint16_t b = (y + x) * 64 / (xsize + ysize);
      frame.SetValue(y, x, 0, r * mul);
      frame.SetValue(y, x, 1, g * mul);
      frame.SetValue(y, x, 2, b * mul);
      frame.SetValue(y, x, 3, g * mul);
    }
  }
  ASSERT_EQ(t.ppf().info.bits_per_sample, 16);
  ASSERT_EQ(t.ppf().info.alpha_bits, 16);

  JXLCompressParams cparams = CompressParamsForLossless();

  JXLDecompressParams dparams;
  dparams.accepted_formats.push_back(t.ppf().frames[0].color.format);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, dparams, pool, &ppf_out), 591, 50);
  EXPECT_EQ(ComputeDistance2(t.ppf(), ppf_out), 0.0);
  EXPECT_EQ(ppf_out.info.bits_per_sample, 16);
  EXPECT_EQ(ppf_out.info.alpha_bits, 16);
  EXPECT_TRUE(test::SameAlpha(t.ppf(), ppf_out));
}

TEST(JxlTest, RoundtripDots) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/cvo9xd_keong_macan_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  ASSERT_NE(t.ppf().info.xsize, 0);
  EXPECT_EQ(t.ppf().info.bits_per_sample, 8);
  EXPECT_EQ(t.ppf().color_encoding.transfer_function,
            JXL_TRANSFER_FUNCTION_SRGB);

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 7);  // kSkirrel
  cparams.AddOption(JXL_ENC_FRAME_SETTING_DOTS, 1);
  cparams.distance = 0.04;

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 273333, 4000);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(0.35));
}

TEST(JxlTest, RoundtripNoise) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  ASSERT_NE(t.ppf().info.xsize, 0);
  EXPECT_EQ(t.ppf().info.bits_per_sample, 8);
  EXPECT_EQ(t.ppf().color_encoding.transfer_function,
            JXL_TRANSFER_FUNCTION_SRGB);

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 7);  // kSkirrel
  cparams.AddOption(JXL_ENC_FRAME_SETTING_NOISE, 1);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, pool, &ppf_out), 39261, 750);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(1.35));
}

TEST(JxlTest, RoundtripLossless8Gray) {
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/cvo9xd_keong_macan_grayscale.png");
  TestImage t;
  t.SetColorEncoding("Gra_D65_Rel_SRG").DecodeFromBytes(orig).ClearMetadata();
  EXPECT_EQ(t.ppf().color_encoding.color_space, JXL_COLOR_SPACE_GRAY);
  EXPECT_EQ(t.ppf().info.bits_per_sample, 8);

  JXLCompressParams cparams = CompressParamsForLossless();

  JXLDecompressParams dparams;
  dparams.accepted_formats.push_back(t.ppf().frames[0].color.format);

  PackedPixelFile ppf_out;
  EXPECT_EQ(Roundtrip(t.ppf(), cparams, dparams, pool, &ppf_out), 92185);
  EXPECT_EQ(ComputeDistance2(t.ppf(), ppf_out), 0.0);
  EXPECT_EQ(ppf_out.color_encoding.color_space, JXL_COLOR_SPACE_GRAY);
  EXPECT_EQ(ppf_out.info.bits_per_sample, 8);
}

TEST(JxlTest, RoundtripAnimation) {
  if (!jxl::extras::CanDecode(jxl::extras::Codec::kGIF)) {
    fprintf(stderr, "Skipping test because of missing GIF decoder.\n");
    return;
  }
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/traffic_light.gif");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  EXPECT_EQ(4, t.ppf().frames.size());

  JXLDecompressParams dparams;
  dparams.accepted_formats.push_back(t.ppf().frames[0].color.format);

  PackedPixelFile ppf_out;
  EXPECT_THAT(Roundtrip(t.ppf(), {}, dparams, pool, &ppf_out),
              IsSlightlyBelow(2600));

  t.CoalesceGIFAnimationWithAlpha();
  ASSERT_EQ(ppf_out.frames.size(), t.ppf().frames.size());
  EXPECT_LE(ButteraugliDistance(t.ppf(), ppf_out),
#if JXL_HIGH_PRECISION
            1.55);
#else
            1.75);
#endif
}

TEST(JxlTest, RoundtripLosslessAnimation) {
  if (!jxl::extras::CanDecode(jxl::extras::Codec::kGIF)) {
    fprintf(stderr, "Skipping test because of missing GIF decoder.\n");
    return;
  }
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/traffic_light.gif");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  EXPECT_EQ(4, t.ppf().frames.size());

  JXLCompressParams cparams = CompressParamsForLossless();

  JXLDecompressParams dparams;
  dparams.accepted_formats.push_back(t.ppf().frames[0].color.format);

  PackedPixelFile ppf_out;
  EXPECT_THAT(Roundtrip(t.ppf(), cparams, dparams, pool, &ppf_out),
              IsSlightlyBelow(958));

  t.CoalesceGIFAnimationWithAlpha();
  ASSERT_EQ(ppf_out.frames.size(), t.ppf().frames.size());
  EXPECT_LE(ButteraugliDistance(t.ppf(), ppf_out), 5e-4);
}

TEST(JxlTest, RoundtripAnimationPatches) {
  if (!jxl::extras::CanDecode(jxl::extras::Codec::kGIF)) {
    fprintf(stderr, "Skipping test because of missing GIF decoder.\n");
    return;
  }
  ThreadPool* pool = nullptr;
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/animation_patches.gif");

  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata();
  ASSERT_EQ(2u, t.ppf().frames.size());

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_PATCHES, 1);

  JXLDecompressParams dparams;
  dparams.accepted_formats.push_back(t.ppf().frames[0].color.format);

  PackedPixelFile ppf_out;
  // 40k with no patches, 27k with patch frames encoded multiple times.
  EXPECT_THAT(Roundtrip(t.ppf(), cparams, dparams, pool, &ppf_out),
              IsSlightlyBelow(16789));
  EXPECT_EQ(ppf_out.frames.size(), t.ppf().frames.size());
  // >10 with broken patches
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(1.0999));
}

size_t RoundtripJpeg(const PaddedBytes& jpeg_in, ThreadPool* pool) {
  std::vector<uint8_t> jpeg_bytes(jpeg_in.data(),
                                  jpeg_in.data() + jpeg_in.size());
  std::vector<uint8_t> compressed;
  EXPECT_TRUE(extras::EncodeImageJXL({}, extras::PackedPixelFile(), &jpeg_bytes,
                                     &compressed));

  jxl::JXLDecompressParams dparams;
  test::DefaultAcceptedFormats(dparams);
  test::SetThreadParallelRunner(dparams, pool);
  std::vector<uint8_t> out;
  jxl::PackedPixelFile ppf;
  EXPECT_TRUE(DecodeImageJXL(compressed.data(), compressed.size(), dparams,
                             nullptr, &ppf, &out));
  EXPECT_EQ(out.size(), jpeg_in.size());
  size_t failures = 0;
  for (size_t i = 0; i < std::min(out.size(), jpeg_in.size()); i++) {
    if (out[i] != jpeg_in[i]) {
      EXPECT_EQ(out[i], jpeg_in[i])
          << "byte mismatch " << i << " " << out[i] << " != " << jpeg_in[i];
      if (++failures > 4) {
        return compressed.size();
      }
    }
  }
  return compressed.size();
}

void RoundtripJpegToPixels(const PaddedBytes& jpeg_in,
                           JXLDecompressParams dparams, ThreadPool* pool,
                           PackedPixelFile* ppf_out) {
  std::vector<uint8_t> jpeg_bytes(jpeg_in.data(),
                                  jpeg_in.data() + jpeg_in.size());
  std::vector<uint8_t> compressed;
  EXPECT_TRUE(extras::EncodeImageJXL({}, extras::PackedPixelFile(), &jpeg_bytes,
                                     &compressed));

  test::DefaultAcceptedFormats(dparams);
  test::SetThreadParallelRunner(dparams, pool);
  EXPECT_TRUE(DecodeImageJXL(compressed.data(), compressed.size(), dparams,
                             nullptr, ppf_out, nullptr));
}

TEST(JxlTest, JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompression444)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower.png.im_q85_444.jpg");
  // JPEG size is 696,659 bytes.
  EXPECT_NEAR(RoundtripJpeg(orig, &pool), 568940u, 10);
}

TEST(JxlTest, JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompressionToPixels)) {
  TEST_LIBJPEG_SUPPORT();
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower.png.im_q85_444.jpg");
  TestImage t;
  t.DecodeFromBytes(orig);

  PackedPixelFile ppf_out;
  RoundtripJpegToPixels(orig, {}, &pool, &ppf_out);
  EXPECT_THAT(ComputeDistance2(t.ppf(), ppf_out), IsSlightlyBelow(12));
}

TEST(JxlTest, JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompressionToPixels420)) {
  TEST_LIBJPEG_SUPPORT();
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower.png.im_q85_420.jpg");
  TestImage t;
  t.DecodeFromBytes(orig);

  PackedPixelFile ppf_out;
  RoundtripJpegToPixels(orig, {}, &pool, &ppf_out);
  EXPECT_THAT(ComputeDistance2(t.ppf(), ppf_out), IsSlightlyBelow(11));
}

TEST(JxlTest,
     JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompressionToPixels420EarlyFlush)) {
  TEST_LIBJPEG_SUPPORT();
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower.png.im_q85_420.jpg");
  TestImage t;
  t.DecodeFromBytes(orig);

  JXLDecompressParams dparams;
  dparams.max_downsampling = 8;

  PackedPixelFile ppf_out;
  RoundtripJpegToPixels(orig, dparams, &pool, &ppf_out);
  EXPECT_THAT(ComputeDistance2(t.ppf(), ppf_out), IsSlightlyBelow(4410));
}

TEST(JxlTest,
     JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompressionToPixels420Mul16)) {
  TEST_LIBJPEG_SUPPORT();
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower_cropped.jpg");
  TestImage t;
  t.DecodeFromBytes(orig);

  PackedPixelFile ppf_out;
  RoundtripJpegToPixels(orig, {}, &pool, &ppf_out);
  EXPECT_THAT(ComputeDistance2(t.ppf(), ppf_out), IsSlightlyBelow(4));
}

TEST(JxlTest,
     JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompressionToPixels_asymmetric)) {
  TEST_LIBJPEG_SUPPORT();
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower.png.im_q85_asymmetric.jpg");
  TestImage t;
  t.DecodeFromBytes(orig);

  PackedPixelFile ppf_out;
  RoundtripJpegToPixels(orig, {}, &pool, &ppf_out);
  EXPECT_THAT(ComputeDistance2(t.ppf(), ppf_out), IsSlightlyBelow(10));
}

TEST(JxlTest, JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompressionGray)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower.png.im_q85_gray.jpg");
  // JPEG size is 456,528 bytes.
  EXPECT_NEAR(RoundtripJpeg(orig, &pool), 387496u, 200);
}

TEST(JxlTest, JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompression420)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower.png.im_q85_420.jpg");
  // JPEG size is 546,797 bytes.
  EXPECT_NEAR(RoundtripJpeg(orig, &pool), 455560u, 10);
}

TEST(JxlTest,
     JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompression_luma_subsample)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig = jxl::test::ReadTestData(
      "jxl/flower/flower.png.im_q85_luma_subsample.jpg");
  // JPEG size is 400,724 bytes.
  EXPECT_NEAR(RoundtripJpeg(orig, &pool), 325354u, 10);
}

TEST(JxlTest, JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompression444_12)) {
  // 444 JPEG that has an interesting sampling-factor (1x2, 1x2, 1x2).
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower.png.im_q85_444_1x2.jpg");
  // JPEG size is 703,874 bytes.
  EXPECT_NEAR(RoundtripJpeg(orig, &pool), 569679u, 10);
}

TEST(JxlTest, JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompression422)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower.png.im_q85_422.jpg");
  // JPEG size is 522,057 bytes.
  EXPECT_NEAR(RoundtripJpeg(orig, &pool), 499282u, 10);
}

TEST(JxlTest, JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompression440)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower.png.im_q85_440.jpg");
  // JPEG size is 603,623 bytes.
  EXPECT_NEAR(RoundtripJpeg(orig, &pool), 501151u, 10);
}

TEST(JxlTest, JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompression_asymmetric)) {
  // 2x vertical downsample of one chroma channel, 2x horizontal downsample of
  // the other.
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower.png.im_q85_asymmetric.jpg");
  // JPEG size is 604,601 bytes.
  EXPECT_NEAR(RoundtripJpeg(orig, &pool), 500602u, 10);
}

TEST(JxlTest, JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompression420Progr)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/flower/flower.png.im_q85_420_progr.jpg");
  // JPEG size is 522,057 bytes.
  EXPECT_NEAR(RoundtripJpeg(orig, &pool), 455499u, 10);
}

TEST(JxlTest, JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompressionMetadata)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/jpeg_reconstruction/1x1_exif_xmp.jpg");
  // JPEG size is 4290 bytes
  EXPECT_NEAR(RoundtripJpeg(orig, &pool), 1400u, 30);
}

TEST(JxlTest,
     JXL_TRANSCODE_JPEG_TEST(RoundtripJpegRecompressionOrientationICC)) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig =
      jxl::test::ReadTestData("jxl/jpeg_reconstruction/sideways_bench.jpg");
  // JPEG size is 15252 bytes
  EXPECT_NEAR(RoundtripJpeg(orig, &pool), 12000u, 470);
  // TODO(jon): investigate why 'Cross-compiling i686-linux-gnu' produces a
  // larger result
}

TEST(JxlTest, RoundtripProgressive) {
  ThreadPoolForTests pool(4);
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/flower/flower.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata().SetDimensions(600, 1024);

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_PROGRESSIVE_DC, 1);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_PROGRESSIVE_AC, 1);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_RESPONSIVE, 1);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out), 62160, 750);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(1.4));
}

TEST(JxlTest, RoundtripProgressiveLevel2Slow) {
  ThreadPoolForTests pool(8);
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/flower/flower.png");
  TestImage t;
  t.DecodeFromBytes(orig).ClearMetadata().SetDimensions(600, 1024);

  JXLCompressParams cparams;
  cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 9);  // kTortoise
  cparams.AddOption(JXL_ENC_FRAME_SETTING_PROGRESSIVE_DC, 2);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_PROGRESSIVE_AC, 1);
  cparams.AddOption(JXL_ENC_FRAME_SETTING_RESPONSIVE, 1);

  PackedPixelFile ppf_out;
  EXPECT_NEAR(Roundtrip(t.ppf(), cparams, {}, &pool, &ppf_out), 71111, 1000);
  EXPECT_THAT(ButteraugliDistance(t.ppf(), ppf_out), IsSlightlyBelow(1.17));
}

TEST(JxlTest, RoundtripUnsignedCustomBitdepthLossless) {
  ThreadPool* pool = nullptr;
  for (uint32_t num_channels = 1; num_channels < 6; ++num_channels) {
    for (JxlEndianness endianness : {JXL_LITTLE_ENDIAN, JXL_BIG_ENDIAN}) {
      for (uint32_t bitdepth = 3; bitdepth <= 16; ++bitdepth) {
        if (bitdepth <= 8 && endianness == JXL_BIG_ENDIAN) continue;
        printf("Testing %u channel unsigned %u bit %s endian lossless.\n",
               num_channels, bitdepth,
               endianness == JXL_LITTLE_ENDIAN ? "little" : "big");
        TestImage t;
        t.SetDimensions(256, 256).SetChannels(num_channels);
        t.SetAllBitDepths(bitdepth).SetEndianness(endianness);
        TestImage::Frame frame = t.AddFrame();
        frame.RandomFill();

        JXLCompressParams cparams = CompressParamsForLossless();
        cparams.input_bitdepth.type = JXL_BIT_DEPTH_FROM_CODESTREAM;

        JXLDecompressParams dparams;
        dparams.accepted_formats.push_back(t.ppf().frames[0].color.format);
        dparams.output_bitdepth.type = JXL_BIT_DEPTH_FROM_CODESTREAM;

        PackedPixelFile ppf_out;
        Roundtrip(t.ppf(), cparams, dparams, pool, &ppf_out);

        ASSERT_TRUE(test::SamePixels(t.ppf(), ppf_out));
      }
    }
  }
}

TEST(JxlTest, LosslessPNMRoundtrip) {
  static const char* kChannels[] = {"", "g", "ga", "rgb", "rgba"};
  static const char* kExtension[] = {"", ".pgm", ".pam", ".ppm", ".pam"};
  for (size_t bit_depth = 1; bit_depth <= 16; ++bit_depth) {
    for (size_t channels = 1; channels <= 4; ++channels) {
      if (bit_depth == 1 && (channels == 2 || channels == 4)) continue;
      std::string extension(kExtension[channels]);
      std::string filename = "jxl/flower/flower_small." +
                             std::string(kChannels[channels]) + ".depth" +
                             std::to_string(bit_depth) + extension;
      const PaddedBytes orig = jxl::test::ReadTestData(filename);
      test::TestImage t;
      if (channels < 3) t.SetColorEncoding("Gra_D65_Rel_SRG");
      t.DecodeFromBytes(orig);

      JXLCompressParams cparams = CompressParamsForLossless();
      cparams.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, 1);  // kLightning
      cparams.input_bitdepth.type = JXL_BIT_DEPTH_FROM_CODESTREAM;

      JXLDecompressParams dparams;
      dparams.accepted_formats.push_back(t.ppf().frames[0].color.format);
      dparams.output_bitdepth.type = JXL_BIT_DEPTH_FROM_CODESTREAM;

      PackedPixelFile ppf_out;
      Roundtrip(t.ppf(), cparams, dparams, nullptr, &ppf_out);

      extras::EncodedImage encoded;
      auto encoder = extras::Encoder::FromExtension(extension);
      ASSERT_TRUE(encoder.get());
      ASSERT_TRUE(encoder->Encode(ppf_out, &encoded, nullptr));
      ASSERT_EQ(encoded.bitstreams.size(), 1);
      ASSERT_EQ(orig.size(), encoded.bitstreams[0].size());
      EXPECT_EQ(0,
                memcmp(orig.data(), encoded.bitstreams[0].data(), orig.size()));
    }
  }
}

}  // namespace
}  // namespace jxl
