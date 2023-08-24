// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdint.h>
#include <stdio.h>

#include <array>
#include <string>
#include <utility>
#include <vector>

#include "lib/extras/codec.h"
#include "lib/extras/dec/jxl.h"
#include "lib/extras/metrics.h"
#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/override.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/color_management.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/enc_butteraugli_comparator.h"
#include "lib/jxl/enc_cache.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_fields.h"
#include "lib/jxl/enc_file.h"
#include "lib/jxl/enc_params.h"
#include "lib/jxl/enc_toc.h"
#include "lib/jxl/image.h"
#include "lib/jxl/image_bundle.h"
#include "lib/jxl/image_ops.h"
#include "lib/jxl/image_test_utils.h"
#include "lib/jxl/modular/encoding/enc_encoding.h"
#include "lib/jxl/modular/encoding/encoding.h"
#include "lib/jxl/modular/encoding/ma_common.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {
using test::Roundtrip;

void TestLosslessGroups(size_t group_size_shift) {
  const PaddedBytes orig = jxl::test::ReadTestData("jxl/flower/flower.png");
  CompressParams cparams;
  cparams.SetLossless();
  cparams.modular_group_size_shift = group_size_shift;

  CodecInOut io_out;

  CodecInOut io;
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io));
  io.ShrinkTo(io.xsize() / 4, io.ysize() / 4);

  size_t compressed_size;
  JXL_EXPECT_OK(Roundtrip(&io, cparams, {}, &io_out, _, &compressed_size));
  EXPECT_LE(compressed_size, 280000u);
  JXL_EXPECT_OK(SamePixels(*io.Main().color(), *io_out.Main().color(), _));
}

TEST(ModularTest, RoundtripLosslessGroups128) { TestLosslessGroups(0); }

TEST(ModularTest, JXL_TSAN_SLOW_TEST(RoundtripLosslessGroups512)) {
  TestLosslessGroups(2);
}

TEST(ModularTest, JXL_TSAN_SLOW_TEST(RoundtripLosslessGroups1024)) {
  TestLosslessGroups(3);
}

TEST(ModularTest, RoundtripLosslessCustomWP_PermuteRCT) {
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  CompressParams cparams;
  cparams.SetLossless();
  // 9 = permute to GBR, to test the special case of permutation-only
  cparams.colorspace = 9;
  // slowest speed so different WP modes are tried
  cparams.speed_tier = SpeedTier::kTortoise;
  cparams.options.predictor = {Predictor::Weighted};

  CodecInOut io_out;

  CodecInOut io;
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io));
  io.ShrinkTo(100, 100);

  size_t compressed_size;
  JXL_EXPECT_OK(Roundtrip(&io, cparams, {}, &io_out, _, &compressed_size));
  EXPECT_LE(compressed_size, 10169u);
  JXL_EXPECT_OK(SamePixels(*io.Main().color(), *io_out.Main().color(), _));
}

TEST(ModularTest, RoundtripLossyDeltaPalette) {
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  CompressParams cparams;
  cparams.modular_mode = true;
  cparams.color_transform = jxl::ColorTransform::kNone;
  cparams.lossy_palette = true;
  cparams.palette_colors = 0;

  CodecInOut io_out;

  CodecInOut io;
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io));
  io.ShrinkTo(300, 100);

  size_t compressed_size;
  JXL_EXPECT_OK(Roundtrip(&io, cparams, {}, &io_out, _, &compressed_size));
  EXPECT_LE(compressed_size, 6800u);
  EXPECT_THAT(ButteraugliDistance(io.frames, io_out.frames, ButteraugliParams(),
                                  GetJxlCms(),
                                  /*distmap=*/nullptr),
              IsSlightlyBelow(1.5));
}
TEST(ModularTest, RoundtripLossyDeltaPaletteWP) {
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  CompressParams cparams;
  cparams.SetLossless();
  cparams.lossy_palette = true;
  cparams.palette_colors = 0;
  cparams.options.predictor = jxl::Predictor::Weighted;

  CodecInOut io_out;

  CodecInOut io;
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io));
  io.ShrinkTo(300, 100);

  size_t compressed_size;
  JXL_EXPECT_OK(Roundtrip(&io, cparams, {}, &io_out, _, &compressed_size));
  EXPECT_LE(compressed_size, 7000u);
  EXPECT_THAT(ButteraugliDistance(io.frames, io_out.frames, ButteraugliParams(),
                                  GetJxlCms(),
                                  /*distmap=*/nullptr),
              IsSlightlyBelow(10.1));
}

TEST(ModularTest, RoundtripLossy) {
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  CompressParams cparams;
  cparams.modular_mode = true;
  cparams.butteraugli_distance = 2.f;
  cparams.SetCms(GetJxlCms());

  CodecInOut io_out;

  CodecInOut io;
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io));

  size_t compressed_size;
  JXL_EXPECT_OK(Roundtrip(&io, cparams, {}, &io_out, _, &compressed_size));
  EXPECT_LE(compressed_size, 30000u);
  EXPECT_THAT(ButteraugliDistance(io.frames, io_out.frames, ButteraugliParams(),
                                  GetJxlCms(),
                                  /*distmap=*/nullptr),
              IsSlightlyBelow(2.3));
}

TEST(ModularTest, RoundtripLossy16) {
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/raw.pixls/DJI-FC6310-16bit_709_v4_krita.png");
  CompressParams cparams;
  cparams.modular_mode = true;
  cparams.butteraugli_distance = 2.f;

  CodecInOut io_out;

  CodecInOut io;
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io));
  JXL_CHECK(!io.metadata.m.have_preview);
  JXL_CHECK(io.frames.size() == 1);
  JXL_CHECK(io.frames[0].TransformTo(ColorEncoding::SRGB(), GetJxlCms()));
  io.metadata.m.color_encoding = ColorEncoding::SRGB();

  size_t compressed_size;
  JXL_EXPECT_OK(Roundtrip(&io, cparams, {}, &io_out, _, &compressed_size));
  EXPECT_LE(compressed_size, 300u);
  EXPECT_THAT(ButteraugliDistance(io.frames, io_out.frames, ButteraugliParams(),
                                  GetJxlCms(),
                                  /*distmap=*/nullptr),
              IsSlightlyBelow(1.6));
}

TEST(ModularTest, RoundtripExtraProperties) {
  constexpr size_t kSize = 250;
  Image image(kSize, kSize, /*bitdepth=*/8, 3);
  ModularOptions options;
  options.max_properties = 4;
  options.predictor = Predictor::Zero;
  Rng rng(0);
  for (size_t y = 0; y < kSize; y++) {
    for (size_t x = 0; x < kSize; x++) {
      image.channel[0].plane.Row(y)[x] = image.channel[2].plane.Row(y)[x] =
          rng.UniformU(0, 9);
    }
  }
  ZeroFillImage(&image.channel[1].plane);
  BitWriter writer;
  ASSERT_TRUE(ModularGenericCompress(image, options, &writer));
  writer.ZeroPadToByte();
  Image decoded(kSize, kSize, /*bitdepth=*/8, image.channel.size());
  for (size_t i = 0; i < image.channel.size(); i++) {
    const Channel& ch = image.channel[i];
    decoded.channel[i] = Channel(ch.w, ch.h, ch.hshift, ch.vshift);
  }
  Status status = true;
  {
    BitReader reader(writer.GetSpan());
    BitReaderScopedCloser closer(&reader, &status);
    ASSERT_TRUE(ModularGenericDecompress(&reader, decoded, /*header=*/nullptr,
                                         /*group_id=*/0, &options));
  }
  ASSERT_TRUE(status);
  ASSERT_EQ(image.channel.size(), decoded.channel.size());
  for (size_t c = 0; c < image.channel.size(); c++) {
    for (size_t y = 0; y < image.channel[c].plane.ysize(); y++) {
      for (size_t x = 0; x < image.channel[c].plane.xsize(); x++) {
        EXPECT_EQ(image.channel[c].plane.Row(y)[x],
                  decoded.channel[c].plane.Row(y)[x])
            << "c = " << c << ", x = " << x << ",  y = " << y;
      }
    }
  }
}

TEST(ModularTest, RoundtripLosslessCustomSqueeze) {
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/tmshre_riaphotographs_srgb8.png");
  CodecInOut io;
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io));

  CompressParams cparams;
  cparams.modular_mode = true;
  cparams.color_transform = jxl::ColorTransform::kNone;
  cparams.butteraugli_distance = 0.f;
  cparams.options.predictor = {Predictor::Zero};
  cparams.speed_tier = SpeedTier::kThunder;
  cparams.responsive = 1;
  // Custom squeeze params, atm just for testing
  SqueezeParams p;
  p.horizontal = true;
  p.in_place = false;
  p.begin_c = 0;
  p.num_c = 3;
  cparams.squeezes.push_back(p);
  p.begin_c = 1;
  p.in_place = true;
  p.horizontal = false;
  cparams.squeezes.push_back(p);

  CodecInOut io2;
  size_t compressed_size;
  JXL_EXPECT_OK(Roundtrip(&io, cparams, {}, &io2, _, &compressed_size));
  EXPECT_LE(compressed_size, 265000u);
  JXL_EXPECT_OK(SamePixels(*io.Main().color(), *io2.Main().color(), _));
}

struct RoundtripLosslessConfig {
  int bitdepth;
  int responsive;
};
class ModularTestParam
    : public ::testing::TestWithParam<RoundtripLosslessConfig> {};

std::vector<RoundtripLosslessConfig> GenerateLosslessTests() {
  std::vector<RoundtripLosslessConfig> all;
  for (int responsive = 0; responsive <= 1; responsive++) {
    for (int bitdepth = 1; bitdepth < 32; bitdepth++) {
      if (responsive && bitdepth > 30) continue;
      all.push_back({bitdepth, responsive});
    }
  }
  return all;
}
std::string LosslessTestDescription(
    const testing::TestParamInfo<ModularTestParam::ParamType>& info) {
  std::stringstream name;
  name << info.param.bitdepth << "bit";
  if (info.param.responsive) name << "Squeeze";
  return name.str();
}

JXL_GTEST_INSTANTIATE_TEST_SUITE_P(RoundtripLossless, ModularTestParam,
                                   testing::ValuesIn(GenerateLosslessTests()),
                                   LosslessTestDescription);

TEST_P(ModularTestParam, RoundtripLossless) {
  RoundtripLosslessConfig config = GetParam();
  int bitdepth = config.bitdepth;
  int responsive = config.responsive;

  ThreadPool* pool = nullptr;
  Rng generator(123);
  const PaddedBytes orig = jxl::test::ReadTestData(
      "external/wesaturate/500px/u76c0g_bliznaca_srgb8.png");
  CodecInOut io1;
  ASSERT_TRUE(SetFromBytes(Span<const uint8_t>(orig), &io1, pool));

  // vary the dimensions a bit, in case of bugs related to
  // even vs odd width or height.
  size_t xsize = 423 + bitdepth;
  size_t ysize = 467 + bitdepth;

  CodecInOut io;
  io.SetSize(xsize, ysize);
  io.metadata.m.color_encoding = jxl::ColorEncoding::SRGB(false);
  io.metadata.m.SetUintSamples(bitdepth);

  double factor = ((1lu << bitdepth) - 1lu);
  double ifactor = 1.0 / factor;
  Image3F noise_added(xsize, ysize);

  for (size_t c = 0; c < 3; c++) {
    for (size_t y = 0; y < ysize; y++) {
      const float* in = io1.Main().color()->PlaneRow(c, y);
      float* out = noise_added.PlaneRow(c, y);
      for (size_t x = 0; x < xsize; x++) {
        // make the least significant bits random
        float f = in[x] + generator.UniformF(0.0f, 1.f / 255.f);
        if (f > 1.f) f = 1.f;
        // quantize to the bitdepth we're testing
        unsigned int u = f * factor + 0.5;
        out[x] = u * ifactor;
      }
    }
  }
  io.SetFromImage(std::move(noise_added), jxl::ColorEncoding::SRGB(false));

  CompressParams cparams;
  cparams.modular_mode = true;
  cparams.color_transform = jxl::ColorTransform::kNone;
  cparams.butteraugli_distance = 0.f;
  cparams.options.predictor = {Predictor::Zero};
  cparams.speed_tier = SpeedTier::kThunder;
  cparams.responsive = responsive;
  CodecInOut io2;
  size_t compressed_size;
  JXL_EXPECT_OK(Roundtrip(&io, cparams, {}, &io2, _, &compressed_size));
  EXPECT_LE(compressed_size, bitdepth * xsize * ysize / 3);
  EXPECT_LE(0, ComputeDistance2(io.Main(), io2.Main(), GetJxlCms()));
  size_t different = 0;
  for (size_t c = 0; c < 3; c++) {
    for (size_t y = 0; y < ysize; y++) {
      const float* in = io.Main().color()->PlaneRow(c, y);
      const float* out = io2.Main().color()->PlaneRow(c, y);
      for (size_t x = 0; x < xsize; x++) {
        uint32_t uin = in[x] * factor + 0.5;
        uint32_t uout = out[x] * factor + 0.5;
        // check that the integer values are identical
        if (uin != uout) different++;
      }
    }
  }
  EXPECT_EQ(different, 0);
}

TEST(ModularTest, RoundtripLosslessCustomFloat) {
  CodecInOut io;
  size_t xsize = 100, ysize = 300;
  io.SetSize(xsize, ysize);
  io.metadata.m.bit_depth.bits_per_sample = 18;
  io.metadata.m.bit_depth.exponent_bits_per_sample = 6;
  io.metadata.m.bit_depth.floating_point_sample = true;
  io.metadata.m.modular_16_bit_buffer_sufficient = false;
  ColorEncoding color_encoding;
  color_encoding.tf.SetTransferFunction(TransferFunction::kLinear);
  color_encoding.SetColorSpace(ColorSpace::kRGB);
  Image3F testimage(xsize, ysize);
  float factor = 1.f / (1 << 14);
  for (size_t c = 0; c < 3; c++) {
    for (size_t y = 0; y < ysize; y++) {
      float* const JXL_RESTRICT row = testimage.PlaneRow(c, y);
      for (size_t x = 0; x < xsize; x++) {
        row[x] = factor * (x ^ y);
      }
    }
  }
  io.SetFromImage(std::move(testimage), color_encoding);
  io.metadata.m.color_encoding = color_encoding;
  io.metadata.m.SetIntensityTarget(255);

  CompressParams cparams;
  cparams.modular_mode = true;
  cparams.color_transform = jxl::ColorTransform::kNone;
  cparams.butteraugli_distance = 0.f;
  cparams.options.predictor = {Predictor::Zero};
  cparams.speed_tier = SpeedTier::kThunder;
  cparams.decoding_speed_tier = 2;

  CodecInOut io2;
  size_t compressed_size;
  JXL_EXPECT_OK(Roundtrip(&io, cparams, {}, &io2, _, &compressed_size));
  EXPECT_LE(compressed_size, 23000u);
  JXL_EXPECT_OK(SamePixels(*io.Main().color(), *io2.Main().color(), _));
}

void WriteHeaders(BitWriter* writer, size_t xsize, size_t ysize) {
  BitWriter::Allotment allotment(writer, 16);
  writer->Write(8, 0xFF);
  writer->Write(8, kCodestreamMarker);
  allotment.ReclaimAndCharge(writer, 0, nullptr);
  CodecMetadata metadata;
  EXPECT_TRUE(metadata.size.Set(xsize, ysize));
  EXPECT_TRUE(WriteSizeHeader(metadata.size, writer, 0, nullptr));
  metadata.m.color_encoding = ColorEncoding::LinearSRGB(/*is_gray=*/true);
  metadata.m.xyb_encoded = false;
  metadata.m.SetUintSamples(31);
  EXPECT_TRUE(WriteImageMetadata(metadata.m, writer, 0, nullptr));
  metadata.transform_data.nonserialized_xyb_encoded = metadata.m.xyb_encoded;
  EXPECT_TRUE(Bundle::Write(metadata.transform_data, writer, 0, nullptr));
  writer->ZeroPadToByte();
  FrameHeader frame_header(&metadata);
  frame_header.encoding = FrameEncoding::kModular;
  frame_header.loop_filter.gab = false;
  frame_header.loop_filter.epf_iters = 0;
  EXPECT_TRUE(WriteFrameHeader(frame_header, writer, nullptr));
}

// Tree with single node, zero predictor, offset is 1 and multiplier is 1,
// entropy code is prefix tree with alphabet size 256 and all bits lengths 8.
void WriteHistograms(BitWriter* writer) {
  writer->Write(1, 1);  // default DC quant
  writer->Write(1, 1);  // has_tree
  // tree histograms
  writer->Write(1, 0);         // LZ77 disabled
  writer->Write(3, 1);         // simple context map
  writer->Write(1, 1);         // prefix code
  writer->Write(7, 0x63);      // UnintConfig(3, 2, 1)
  writer->Write(12, 0xfef);    // alphabet_size = 256
  writer->Write(32, 0x10003);  // all bit lengths 8
  // tree tokens
  writer->Write(8, 0);   // tree leaf
  writer->Write(8, 0);   // zero predictor
  writer->Write(8, 64);  // offset = UnpackSigned(ReverseBits(64)) = 1
  writer->Write(16, 0);  // multiplier = 1
  // histograms
  writer->Write(1, 0);         // LZ77 disabled
  writer->Write(1, 1);         // prefix code
  writer->Write(7, 0x63);      // UnintConfig(3, 2, 1)
  writer->Write(12, 0xfef);    // alphabet_size = 256
  writer->Write(32, 0x10003);  // all bit lengths 8
}

TEST(ModularTest, PredictorIntegerOverflow) {
  const size_t xsize = 1;
  const size_t ysize = 1;
  BitWriter writer;
  WriteHeaders(&writer, xsize, ysize);
  std::vector<BitWriter> group_codes(1);
  {
    BitWriter* bw = &group_codes[0];
    BitWriter::Allotment allotment(bw, 1 << 20);
    WriteHistograms(bw);
    GroupHeader header;
    header.use_global_tree = true;
    EXPECT_TRUE(Bundle::Write(header, bw, 0, nullptr));
    // After UnpackSigned this becomes (1 << 31) - 1, the largest pixel_type,
    // and after adding the offset we get -(1 << 31).
    bw->Write(8, 119);
    bw->Write(28, 0xfffffff);
    bw->ZeroPadToByte();
    allotment.ReclaimAndCharge(bw, 0, nullptr);
  }
  EXPECT_TRUE(WriteGroupOffsets(group_codes, nullptr, &writer, nullptr));
  writer.AppendByteAligned(group_codes);

  PaddedBytes compressed = std::move(writer).TakeBytes();
  extras::PackedPixelFile ppf;
  extras::JXLDecompressParams params;
  params.accepted_formats.push_back({1, JXL_TYPE_FLOAT, JXL_NATIVE_ENDIAN, 0});
  EXPECT_TRUE(DecodeImageJXL(compressed.data(), compressed.size(), params,
                             nullptr, &ppf));
  ASSERT_EQ(1, ppf.frames.size());
  const auto& img = ppf.frames[0].color;
  const auto pixels = reinterpret_cast<const float*>(img.pixels());
  EXPECT_EQ(-1.0f, pixels[0]);
}

TEST(ModularTest, UnsqueezeIntegerOverflow) {
  // Image width is 9 so we can test both the SIMD and non-vector code paths.
  const size_t xsize = 9;
  const size_t ysize = 2;
  BitWriter writer;
  WriteHeaders(&writer, xsize, ysize);
  std::vector<BitWriter> group_codes(1);
  {
    BitWriter* bw = &group_codes[0];
    BitWriter::Allotment allotment(bw, 1 << 20);
    WriteHistograms(bw);
    GroupHeader header;
    header.use_global_tree = true;
    header.transforms.emplace_back();
    header.transforms[0].id = TransformId::kSqueeze;
    SqueezeParams params;
    params.horizontal = false;
    params.in_place = true;
    params.begin_c = 0;
    params.num_c = 1;
    header.transforms[0].squeezes.emplace_back(params);
    EXPECT_TRUE(Bundle::Write(header, bw, 0, nullptr));
    for (size_t i = 0; i < xsize * ysize; ++i) {
      // After UnpackSigned and adding offset, this becomes (1 << 31) - 1, both
      // in the image and in the residual channels, and unsqueeze makes them
      // ~(3 << 30) and (1 << 30) (in pixel_type_w) and the first wraps around
      // to about -(1 << 30).
      bw->Write(8, 119);
      bw->Write(28, 0xffffffe);
    }
    bw->ZeroPadToByte();
    allotment.ReclaimAndCharge(bw, 0, nullptr);
  }
  EXPECT_TRUE(WriteGroupOffsets(group_codes, nullptr, &writer, nullptr));
  writer.AppendByteAligned(group_codes);

  PaddedBytes compressed = std::move(writer).TakeBytes();
  extras::PackedPixelFile ppf;
  extras::JXLDecompressParams params;
  params.accepted_formats.push_back({1, JXL_TYPE_FLOAT, JXL_NATIVE_ENDIAN, 0});
  EXPECT_TRUE(DecodeImageJXL(compressed.data(), compressed.size(), params,
                             nullptr, &ppf));
  ASSERT_EQ(1, ppf.frames.size());
  const auto& img = ppf.frames[0].color;
  const auto pixels = reinterpret_cast<const float*>(img.pixels());
  for (size_t x = 0; x < xsize; ++x) {
    EXPECT_NEAR(-0.5f, pixels[x], 1e-10);
    EXPECT_NEAR(0.5f, pixels[xsize + x], 1e-10);
  }
}

}  // namespace
}  // namespace jxl
