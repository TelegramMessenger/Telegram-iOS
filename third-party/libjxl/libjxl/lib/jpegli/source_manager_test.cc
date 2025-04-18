// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>

#include <cmath>
#include <vector>

#include "lib/jpegli/decode.h"
#include "lib/jpegli/test_utils.h"
#include "lib/jpegli/testing.h"
#include "lib/jxl/base/status.h"

namespace jpegli {
namespace {

void ReadOutputImage(j_decompress_ptr cinfo, TestImage* output) {
  jpegli_read_header(cinfo, /*require_image=*/TRUE);
  jpegli_start_decompress(cinfo);
  output->ysize = cinfo->output_height;
  output->xsize = cinfo->output_width;
  output->components = cinfo->num_components;
  output->AllocatePixels();
  size_t stride = cinfo->output_width * cinfo->num_components;
  while (cinfo->output_scanline < cinfo->output_height) {
    JSAMPROW scanline = &output->pixels[cinfo->output_scanline * stride];
    jpegli_read_scanlines(cinfo, &scanline, 1);
  }
  jpegli_finish_decompress(cinfo);
}

struct TestConfig {
  std::string fn;
  std::string fn_desc;
  DecompressParams dparams;
};

class SourceManagerTestParam : public ::testing::TestWithParam<TestConfig> {};

namespace {
FILE* MemOpen(const std::vector<uint8_t>& data) {
  FILE* src = tmpfile();
  if (!src) return nullptr;
  fwrite(data.data(), 1, data.size(), src);
  rewind(src);
  return src;
}
}  // namespace

TEST_P(SourceManagerTestParam, TestStdioSourceManager) {
  TestConfig config = GetParam();
  std::vector<uint8_t> compressed = ReadTestData(config.fn.c_str());
  if (config.dparams.size_factor < 1.0) {
    compressed.resize(compressed.size() * config.dparams.size_factor);
  }
  FILE* src = MemOpen(compressed);
  ASSERT_TRUE(src);
  TestImage output0;
  jpeg_decompress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    jpegli_stdio_src(&cinfo, src);
    ReadOutputImage(&cinfo, &output0);
    return true;
  };
  bool ok = try_catch_block();
  fclose(src);
  ASSERT_TRUE(ok);
  jpegli_destroy_decompress(&cinfo);

  TestImage output1;
  DecodeWithLibjpeg(CompressParams(), DecompressParams(), compressed, &output1);
  VerifyOutputImage(output1, output0, 1.0f);
}

TEST_P(SourceManagerTestParam, TestMemSourceManager) {
  TestConfig config = GetParam();
  std::vector<uint8_t> compressed = ReadTestData(config.fn.c_str());
  if (config.dparams.size_factor < 1.0f) {
    compressed.resize(compressed.size() * config.dparams.size_factor);
  }
  TestImage output0;
  jpeg_decompress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    jpegli_mem_src(&cinfo, compressed.data(), compressed.size());
    ReadOutputImage(&cinfo, &output0);
    return true;
  };
  ASSERT_TRUE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);

  TestImage output1;
  DecodeWithLibjpeg(CompressParams(), DecompressParams(), compressed, &output1);
  VerifyOutputImage(output1, output0, 1.0f);
}

std::vector<TestConfig> GenerateTests() {
  std::vector<TestConfig> all_tests;
  {
    std::vector<std::pair<std::string, std::string>> testfiles({
        {"jxl/flower/flower.png.im_q85_444.jpg", "Q85YUV444"},
        {"jxl/flower/flower.png.im_q85_420.jpg", "Q85YUV420"},
        {"jxl/flower/flower.png.im_q85_420_R13B.jpg", "Q85YUV420R13B"},
    });
    for (const auto& it : testfiles) {
      for (float size_factor : {0.1f, 0.33f, 0.5f, 0.75f}) {
        TestConfig config;
        config.fn = it.first;
        config.fn_desc = it.second;
        config.dparams.size_factor = size_factor;
        all_tests.push_back(config);
      }
    }
    return all_tests;
  }
}

std::ostream& operator<<(std::ostream& os, const TestConfig& c) {
  os << c.fn_desc;
  if (c.dparams.size_factor < 1.0f) {
    os << "Partial" << static_cast<int>(c.dparams.size_factor * 100) << "p";
  }
  return os;
}

std::string TestDescription(
    const testing::TestParamInfo<SourceManagerTestParam::ParamType>& info) {
  std::stringstream name;
  name << info.param;
  return name.str();
}

JPEGLI_INSTANTIATE_TEST_SUITE_P(SourceManagerTest, SourceManagerTestParam,
                                testing::ValuesIn(GenerateTests()),
                                TestDescription);

}  // namespace
}  // namespace jpegli
