// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <vector>

#include "lib/jpegli/decode.h"
#include "lib/jpegli/encode.h"
#include "lib/jpegli/test_utils.h"
#include "lib/jpegli/testing.h"
#include "lib/jxl/base/status.h"

namespace jpegli {
namespace {

void TranscodeWithJpegli(const std::vector<uint8_t>& jpeg_input,
                         const CompressParams& jparams,
                         std::vector<uint8_t>* jpeg_output) {
  jpeg_decompress_struct dinfo = {};
  jpeg_compress_struct cinfo = {};
  uint8_t* transcoded_data = nullptr;
  unsigned long transcoded_size;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    dinfo.err = cinfo.err;
    dinfo.client_data = cinfo.client_data;
    jpegli_create_decompress(&dinfo);
    jpegli_mem_src(&dinfo, jpeg_input.data(), jpeg_input.size());
    EXPECT_EQ(JPEG_REACHED_SOS,
              jpegli_read_header(&dinfo, /*require_image=*/TRUE));
    jvirt_barray_ptr* coef_arrays = jpegli_read_coefficients(&dinfo);
    JXL_CHECK(coef_arrays != nullptr);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &transcoded_data, &transcoded_size);
    jpegli_copy_critical_parameters(&dinfo, &cinfo);
    jpegli_set_progressive_level(&cinfo, jparams.progressive_mode);
    cinfo.optimize_coding = jparams.optimize_coding;
    jpegli_write_coefficients(&cinfo, coef_arrays);
    jpegli_finish_compress(&cinfo);
    jpegli_finish_decompress(&dinfo);
    return true;
  };
  ASSERT_TRUE(try_catch_block());
  jpegli_destroy_decompress(&dinfo);
  jpegli_destroy_compress(&cinfo);
  if (transcoded_data) {
    jpeg_output->assign(transcoded_data, transcoded_data + transcoded_size);
    free(transcoded_data);
  }
}

struct TestConfig {
  TestImage input;
  CompressParams jparams;
};

class TranscodeAPITestParam : public ::testing::TestWithParam<TestConfig> {};

TEST_P(TranscodeAPITestParam, TestAPI) {
  TestConfig config = GetParam();
  CompressParams& jparams = config.jparams;
  GeneratePixels(&config.input);

  // Start with sequential non-optimized jpeg.
  jparams.progressive_mode = 0;
  jparams.optimize_coding = 0;
  std::vector<uint8_t> compressed;
  ASSERT_TRUE(EncodeWithJpegli(config.input, jparams, &compressed));
  TestImage output0;
  DecodeWithLibjpeg(jparams, DecompressParams(), compressed, &output0);

  // Transcode first to a sequential optimized jpeg, and then further to
  // a progressive jpeg.
  for (int progr : {0, 2}) {
    std::vector<uint8_t> transcoded;
    jparams.progressive_mode = progr;
    jparams.optimize_coding = 1;
    TranscodeWithJpegli(compressed, jparams, &transcoded);

    // We expect a size reduction of at least 2%.
    EXPECT_LT(transcoded.size(), compressed.size() * 0.98f);

    // Verify that transcoding is lossless.
    TestImage output1;
    DecodeWithLibjpeg(jparams, DecompressParams(), transcoded, &output1);
    ASSERT_EQ(output0.pixels.size(), output1.pixels.size());
    EXPECT_EQ(0, memcmp(output0.pixels.data(), output1.pixels.data(),
                        output0.pixels.size()));
    compressed = transcoded;
  }
}

std::vector<TestConfig> GenerateTests() {
  std::vector<TestConfig> all_tests;
  const size_t xsize0 = 1024;
  const size_t ysize0 = 768;
  for (int dxsize : {0, 1, 8, 9}) {
    for (int dysize : {0, 1, 8, 9}) {
      for (int h_sampling : {1, 2}) {
        for (int v_sampling : {1, 2}) {
          TestConfig config;
          config.input.xsize = xsize0 + dxsize;
          config.input.ysize = ysize0 + dysize;
          config.jparams.h_sampling = {h_sampling, 1, 1};
          config.jparams.v_sampling = {v_sampling, 1, 1};
          all_tests.push_back(config);
        }
      }
    }
  }
  return all_tests;
}

std::ostream& operator<<(std::ostream& os, const TestConfig& c) {
  os << c.input;
  os << c.jparams;
  return os;
}

std::string TestDescription(
    const testing::TestParamInfo<TranscodeAPITestParam::ParamType>& info) {
  std::stringstream name;
  name << info.param;
  return name.str();
}

JPEGLI_INSTANTIATE_TEST_SUITE_P(TranscodeAPITest, TranscodeAPITestParam,
                                testing::ValuesIn(GenerateTests()),
                                TestDescription);

}  // namespace
}  // namespace jpegli
