// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#if JPEGXL_ENABLE_JPEGLI

#include "lib/extras/dec/jpegli.h"

#include <jxl/color_encoding.h>
#include <stdint.h>

#include <memory>
#include <string>

#include "lib/extras/dec/color_hints.h"
#include "lib/extras/dec/decode.h"
#include "lib/extras/dec/jpg.h"
#include "lib/extras/enc/encode.h"
#include "lib/extras/enc/jpegli.h"
#include "lib/extras/enc/jpg.h"
#include "lib/extras/packed_image.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/test_image.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace extras {
namespace {

using test::Butteraugli3Norm;
using test::ButteraugliDistance;
using test::TestImage;

Status ReadTestImage(const std::string& pathname, PackedPixelFile* ppf) {
  const PaddedBytes encoded = jxl::test::ReadTestData(pathname);
  ColorHints color_hints;
  if (pathname.find(".ppm") != std::string::npos) {
    color_hints.Add("color_space", "RGB_D65_SRG_Rel_SRG");
  } else if (pathname.find(".pgm") != std::string::npos) {
    color_hints.Add("color_space", "Gra_D65_Rel_SRG");
  }
  return DecodeBytes(Span<const uint8_t>(encoded), color_hints, ppf);
}

std::vector<uint8_t> GetAppData(const std::vector<uint8_t>& compressed) {
  std::vector<uint8_t> result;
  size_t pos = 2;  // After SOI
  while (pos + 4 < compressed.size()) {
    if (compressed[pos] != 0xff || compressed[pos + 1] < 0xe0 ||
        compressed[pos + 1] > 0xf0) {
      break;
    }
    size_t len = (compressed[pos + 2] << 8) + compressed[pos + 3] + 2;
    if (pos + len > compressed.size()) {
      break;
    }
    result.insert(result.end(), &compressed[pos], &compressed[pos] + len);
    pos += len;
  }
  return result;
}

Status DecodeWithLibjpeg(const std::vector<uint8_t>& compressed,
                         PackedPixelFile* ppf,
                         const JPGDecompressParams* dparams = nullptr) {
  return DecodeImageJPG(Span<const uint8_t>(compressed), ColorHints(), ppf,
                        /*constraints=*/nullptr, dparams);
}

Status EncodeWithLibjpeg(const PackedPixelFile& ppf, int quality,
                         std::vector<uint8_t>* compressed) {
  std::unique_ptr<Encoder> encoder = GetJPEGEncoder();
  encoder->SetOption("q", std::to_string(quality));
  EncodedImage encoded;
  JXL_RETURN_IF_ERROR(encoder->Encode(ppf, &encoded));
  JXL_RETURN_IF_ERROR(!encoded.bitstreams.empty());
  *compressed = std::move(encoded.bitstreams[0]);
  return true;
}

std::string Description(const JxlColorEncoding& color_encoding) {
  ColorEncoding c_enc;
  JXL_CHECK(ConvertExternalToInternalColorEncoding(color_encoding, &c_enc));
  return Description(c_enc);
}

float BitsPerPixel(const PackedPixelFile& ppf,
                   const std::vector<uint8_t>& compressed) {
  const size_t num_pixels = ppf.info.xsize * ppf.info.ysize;
  return compressed.size() * 8.0 / num_pixels;
}

TEST(JpegliTest, JpegliSRGBDecodeTest) {
  TEST_LIBJPEG_SUPPORT();
  std::string testimage = "jxl/flower/flower_small.rgb.depth8.ppm";
  PackedPixelFile ppf0;
  ASSERT_TRUE(ReadTestImage(testimage, &ppf0));
  EXPECT_EQ("RGB_D65_SRG_Rel_SRG", Description(ppf0.color_encoding));
  EXPECT_EQ(8, ppf0.info.bits_per_sample);

  std::vector<uint8_t> compressed;
  ASSERT_TRUE(EncodeWithLibjpeg(ppf0, 90, &compressed));

  PackedPixelFile ppf1;
  ASSERT_TRUE(DecodeWithLibjpeg(compressed, &ppf1));
  PackedPixelFile ppf2;
  JpegDecompressParams dparams;
  ASSERT_TRUE(DecodeJpeg(compressed, dparams, nullptr, &ppf2));
  EXPECT_LT(ButteraugliDistance(ppf0, ppf2), ButteraugliDistance(ppf0, ppf1));
}

TEST(JpegliTest, JpegliGrayscaleDecodeTest) {
  TEST_LIBJPEG_SUPPORT();
  std::string testimage = "jxl/flower/flower_small.g.depth8.pgm";
  PackedPixelFile ppf0;
  ASSERT_TRUE(ReadTestImage(testimage, &ppf0));
  EXPECT_EQ("Gra_D65_Rel_SRG", Description(ppf0.color_encoding));
  EXPECT_EQ(8, ppf0.info.bits_per_sample);

  std::vector<uint8_t> compressed;
  ASSERT_TRUE(EncodeWithLibjpeg(ppf0, 90, &compressed));

  PackedPixelFile ppf1;
  ASSERT_TRUE(DecodeWithLibjpeg(compressed, &ppf1));
  PackedPixelFile ppf2;
  JpegDecompressParams dparams;
  ASSERT_TRUE(DecodeJpeg(compressed, dparams, nullptr, &ppf2));
  EXPECT_LT(ButteraugliDistance(ppf0, ppf2), ButteraugliDistance(ppf0, ppf1));
}

TEST(JpegliTest, JpegliXYBEncodeTest) {
  TEST_LIBJPEG_SUPPORT();
  std::string testimage = "jxl/flower/flower_small.rgb.depth8.ppm";
  PackedPixelFile ppf_in;
  ASSERT_TRUE(ReadTestImage(testimage, &ppf_in));
  EXPECT_EQ("RGB_D65_SRG_Rel_SRG", Description(ppf_in.color_encoding));
  EXPECT_EQ(8, ppf_in.info.bits_per_sample);

  std::vector<uint8_t> compressed;
  JpegSettings settings;
  settings.xyb = true;
  ASSERT_TRUE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));

  PackedPixelFile ppf_out;
  ASSERT_TRUE(DecodeWithLibjpeg(compressed, &ppf_out));
  EXPECT_THAT(BitsPerPixel(ppf_in, compressed), IsSlightlyBelow(1.45f));
  EXPECT_THAT(ButteraugliDistance(ppf_in, ppf_out), IsSlightlyBelow(1.32f));
}

TEST(JpegliTest, JpegliDecodeTestLargeSmoothArea) {
  TEST_LIBJPEG_SUPPORT();
  TestImage t;
  const size_t xsize = 2070;
  const size_t ysize = 1063;
  t.SetDimensions(xsize, ysize).SetChannels(3);
  t.SetAllBitDepths(8).SetEndianness(JXL_NATIVE_ENDIAN);
  TestImage::Frame frame = t.AddFrame();
  frame.RandomFill();
  // Create a large smooth area in the top half of the image. This is to test
  // that the bias statistics calculation can handle many blocks with all-zero
  // AC coefficients.
  for (size_t y = 0; y < ysize / 2; ++y) {
    for (size_t x = 0; x < xsize; ++x) {
      for (size_t c = 0; c < 3; ++c) {
        frame.SetValue(y, x, c, 0.5f);
      }
    }
  }
  const PackedPixelFile& ppf0 = t.ppf();

  std::vector<uint8_t> compressed;
  ASSERT_TRUE(EncodeWithLibjpeg(ppf0, 90, &compressed));

  PackedPixelFile ppf1;
  JpegDecompressParams dparams;
  ASSERT_TRUE(DecodeJpeg(compressed, dparams, nullptr, &ppf1));
  EXPECT_LT(ButteraugliDistance(ppf0, ppf1), 3.0f);
}

TEST(JpegliTest, JpegliYUVEncodeTest) {
  TEST_LIBJPEG_SUPPORT();
  std::string testimage = "jxl/flower/flower_small.rgb.depth8.ppm";
  PackedPixelFile ppf_in;
  ASSERT_TRUE(ReadTestImage(testimage, &ppf_in));
  EXPECT_EQ("RGB_D65_SRG_Rel_SRG", Description(ppf_in.color_encoding));
  EXPECT_EQ(8, ppf_in.info.bits_per_sample);

  std::vector<uint8_t> compressed;
  JpegSettings settings;
  settings.xyb = false;
  ASSERT_TRUE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));

  PackedPixelFile ppf_out;
  ASSERT_TRUE(DecodeWithLibjpeg(compressed, &ppf_out));
  EXPECT_THAT(BitsPerPixel(ppf_in, compressed), IsSlightlyBelow(1.7f));
  EXPECT_THAT(ButteraugliDistance(ppf_in, ppf_out), IsSlightlyBelow(1.32f));
}

TEST(JpegliTest, JpegliYUVChromaSubsamplingEncodeTest) {
  TEST_LIBJPEG_SUPPORT();
  std::string testimage = "jxl/flower/flower_small.rgb.depth8.ppm";
  PackedPixelFile ppf_in;
  ASSERT_TRUE(ReadTestImage(testimage, &ppf_in));
  EXPECT_EQ("RGB_D65_SRG_Rel_SRG", Description(ppf_in.color_encoding));
  EXPECT_EQ(8, ppf_in.info.bits_per_sample);

  std::vector<uint8_t> compressed;
  JpegSettings settings;
  for (const char* sampling : {"440", "422", "420"}) {
    settings.xyb = false;
    settings.chroma_subsampling = std::string(sampling);
    ASSERT_TRUE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));

    PackedPixelFile ppf_out;
    ASSERT_TRUE(DecodeWithLibjpeg(compressed, &ppf_out));
    EXPECT_LE(BitsPerPixel(ppf_in, compressed), 1.55f);
    EXPECT_LE(ButteraugliDistance(ppf_in, ppf_out), 1.82f);
  }
}

TEST(JpegliTest, JpegliYUVEncodeTestNoAq) {
  TEST_LIBJPEG_SUPPORT();
  std::string testimage = "jxl/flower/flower_small.rgb.depth8.ppm";
  PackedPixelFile ppf_in;
  ASSERT_TRUE(ReadTestImage(testimage, &ppf_in));
  EXPECT_EQ("RGB_D65_SRG_Rel_SRG", Description(ppf_in.color_encoding));
  EXPECT_EQ(8, ppf_in.info.bits_per_sample);

  std::vector<uint8_t> compressed;
  JpegSettings settings;
  settings.xyb = false;
  settings.use_adaptive_quantization = false;
  ASSERT_TRUE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));

  PackedPixelFile ppf_out;
  ASSERT_TRUE(DecodeWithLibjpeg(compressed, &ppf_out));
  EXPECT_THAT(BitsPerPixel(ppf_in, compressed), IsSlightlyBelow(1.85f));
  EXPECT_THAT(ButteraugliDistance(ppf_in, ppf_out), IsSlightlyBelow(1.25f));
}

TEST(JpegliTest, JpegliHDRRoundtripTest) {
  std::string testimage = "jxl/hdr_room.png";
  PackedPixelFile ppf_in;
  ASSERT_TRUE(ReadTestImage(testimage, &ppf_in));
  EXPECT_EQ("RGB_D65_202_Rel_HLG", Description(ppf_in.color_encoding));
  EXPECT_EQ(16, ppf_in.info.bits_per_sample);

  std::vector<uint8_t> compressed;
  JpegSettings settings;
  settings.xyb = false;
  ASSERT_TRUE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));

  PackedPixelFile ppf_out;
  JpegDecompressParams dparams;
  dparams.output_data_type = JXL_TYPE_UINT16;
  ASSERT_TRUE(DecodeJpeg(compressed, dparams, nullptr, &ppf_out));
  EXPECT_THAT(BitsPerPixel(ppf_in, compressed), IsSlightlyBelow(2.95f));
  EXPECT_THAT(ButteraugliDistance(ppf_in, ppf_out), IsSlightlyBelow(1.05f));
}

TEST(JpegliTest, JpegliSetAppData) {
  std::string testimage = "jxl/flower/flower_small.rgb.depth8.ppm";
  PackedPixelFile ppf_in;
  ASSERT_TRUE(ReadTestImage(testimage, &ppf_in));
  EXPECT_EQ("RGB_D65_SRG_Rel_SRG", Description(ppf_in.color_encoding));
  EXPECT_EQ(8, ppf_in.info.bits_per_sample);

  std::vector<uint8_t> compressed;
  JpegSettings settings;
  settings.app_data = {0xff, 0xe3, 0, 4, 0, 1};
  EXPECT_TRUE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));
  EXPECT_EQ(settings.app_data, GetAppData(compressed));

  settings.app_data = {0xff, 0xe3, 0, 6, 0, 1, 2, 3, 0xff, 0xef, 0, 4, 0, 1};
  EXPECT_TRUE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));
  EXPECT_EQ(settings.app_data, GetAppData(compressed));

  settings.xyb = true;
  EXPECT_TRUE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));
  EXPECT_EQ(0, memcmp(settings.app_data.data(), GetAppData(compressed).data(),
                      settings.app_data.size()));

  settings.xyb = false;
  settings.app_data = {0};
  EXPECT_FALSE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));

  settings.app_data = {0xff, 0xe0};
  EXPECT_FALSE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));

  settings.app_data = {0xff, 0xe0, 0, 2};
  EXPECT_FALSE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));

  settings.app_data = {0xff, 0xeb, 0, 4, 0};
  EXPECT_FALSE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));

  settings.app_data = {0xff, 0xeb, 0, 4, 0, 1, 2, 3};
  EXPECT_FALSE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));

  settings.app_data = {0xff, 0xab, 0, 4, 0, 1};
  EXPECT_FALSE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));

  settings.xyb = false;
  settings.app_data = {
      0xff, 0xeb, 0,    4,    0,    1,                       //
      0xff, 0xe2, 0,    20,   0x49, 0x43, 0x43, 0x5F, 0x50,  //
      0x52, 0x4F, 0x46, 0x49, 0x4C, 0x45, 0x00, 0,    1,     //
      0,    0,    0,    0,                                   //
  };
  EXPECT_TRUE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));
  EXPECT_EQ(settings.app_data, GetAppData(compressed));

  settings.xyb = true;
  EXPECT_FALSE(EncodeJpeg(ppf_in, settings, nullptr, &compressed));
}

struct TestConfig {
  int num_colors;
  int passes;
  int dither;
};

class JpegliColorQuantTestParam : public ::testing::TestWithParam<TestConfig> {
};

TEST_P(JpegliColorQuantTestParam, JpegliColorQuantizeTest) {
  TEST_LIBJPEG_SUPPORT();
  TestConfig config = GetParam();
  std::string testimage = "jxl/flower/flower_small.rgb.depth8.ppm";
  PackedPixelFile ppf0;
  ASSERT_TRUE(ReadTestImage(testimage, &ppf0));
  EXPECT_EQ("RGB_D65_SRG_Rel_SRG", Description(ppf0.color_encoding));
  EXPECT_EQ(8, ppf0.info.bits_per_sample);

  std::vector<uint8_t> compressed;
  ASSERT_TRUE(EncodeWithLibjpeg(ppf0, 90, &compressed));

  PackedPixelFile ppf1;
  JPGDecompressParams dparams1;
  dparams1.two_pass_quant = (config.passes == 2);
  dparams1.num_colors = config.num_colors;
  dparams1.dither_mode = config.dither;
  ASSERT_TRUE(DecodeWithLibjpeg(compressed, &ppf1, &dparams1));

  PackedPixelFile ppf2;
  JpegDecompressParams dparams2;
  dparams2.two_pass_quant = (config.passes == 2);
  dparams2.num_colors = config.num_colors;
  dparams2.dither_mode = config.dither;
  ASSERT_TRUE(DecodeJpeg(compressed, dparams2, nullptr, &ppf2));

  double dist1 = Butteraugli3Norm(ppf0, ppf1);
  double dist2 = Butteraugli3Norm(ppf0, ppf2);
  printf("distance: %f  vs %f\n", dist2, dist1);
  if (config.passes == 1) {
    if (config.num_colors == 16 && config.dither == 2) {
      // TODO(szabadka) Fix this case.
      EXPECT_LT(dist2, dist1 * 1.5);
    } else {
      EXPECT_LT(dist2, dist1 * 1.05);
    }
  } else if (config.num_colors > 64) {
    // TODO(szabadka) Fix 2pass quantization for <= 64 colors.
    EXPECT_LT(dist2, dist1 * 1.1);
  } else if (config.num_colors > 32) {
    EXPECT_LT(dist2, dist1 * 1.2);
  } else {
    EXPECT_LT(dist2, dist1 * 1.7);
  }
}

std::vector<TestConfig> GenerateTests() {
  std::vector<TestConfig> all_tests;
  for (int num_colors = 8; num_colors <= 256; num_colors *= 2) {
    for (int passes = 1; passes <= 2; ++passes) {
      for (int dither = 0; dither < 3; dither += passes) {
        TestConfig config;
        config.num_colors = num_colors;
        config.passes = passes;
        config.dither = dither;
        all_tests.push_back(config);
      }
    }
  }
  return all_tests;
}

std::ostream& operator<<(std::ostream& os, const TestConfig& c) {
  static constexpr const char* kDitherModeStr[] = {"No", "Ordered", "FS"};
  os << c.passes << "pass";
  os << c.num_colors << "colors";
  os << kDitherModeStr[c.dither] << "dither";
  return os;
}

std::string TestDescription(const testing::TestParamInfo<TestConfig>& info) {
  std::stringstream name;
  name << info.param;
  return name.str();
}

JXL_GTEST_INSTANTIATE_TEST_SUITE_P(JpegliColorQuantTest,
                                   JpegliColorQuantTestParam,
                                   testing::ValuesIn(GenerateTests()),
                                   TestDescription);

}  // namespace
}  // namespace extras
}  // namespace jxl
#endif  // JPEGXL_ENABLE_JPEGLI
