// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>

#include <algorithm>
#include <cmath>
#include <vector>

#include "lib/jpegli/encode.h"
#include "lib/jpegli/error.h"
#include "lib/jpegli/test_utils.h"
#include "lib/jpegli/testing.h"
#include "lib/jxl/sanitizers.h"

namespace jpegli {
namespace {

struct TestConfig {
  TestImage input;
  CompressParams jparams;
  JpegIOMode input_mode = PIXELS;
  double max_bpp;
  double max_dist;
};

class EncodeAPITestParam : public ::testing::TestWithParam<TestConfig> {};

void GenerateInput(JpegIOMode input_mode, const CompressParams& jparams,
                   TestImage* input) {
  GeneratePixels(input);
  if (input_mode == RAW_DATA) {
    GenerateRawData(jparams, input);
  } else if (input_mode == COEFFICIENTS) {
    GenerateCoeffs(jparams, input);
  }
}

TEST_P(EncodeAPITestParam, TestAPI) {
  TestConfig config = GetParam();
  GenerateInput(config.input_mode, config.jparams, &config.input);
  std::vector<uint8_t> compressed;
  ASSERT_TRUE(EncodeWithJpegli(config.input, config.jparams, &compressed));
  if (config.jparams.icc.empty()) {
    double bpp =
        compressed.size() * 8.0 / (config.input.xsize * config.input.ysize);
    printf("bpp: %f\n", bpp);
    EXPECT_LT(bpp, config.max_bpp);
  }
  DecompressParams dparams;
  dparams.output_mode =
      config.input_mode == COEFFICIENTS ? COEFFICIENTS : PIXELS;
  if (config.jparams.set_jpeg_colorspace &&
      config.jparams.jpeg_color_space == JCS_GRAYSCALE) {
    ConvertToGrayscale(&config.input);
  } else {
    dparams.set_out_color_space = true;
    dparams.out_color_space = config.input.color_space;
  }
  TestImage output;
  DecodeWithLibjpeg(config.jparams, dparams, compressed, &output);
  VerifyOutputImage(config.input, output, config.max_dist);
}

TEST(EncodeAPITest, ReuseCinfoSameImageTwice) {
  TestImage input;
  input.xsize = 129;
  input.ysize = 73;
  CompressParams jparams;
  GenerateInput(PIXELS, jparams, &input);
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  std::vector<uint8_t> compressed0;
  std::vector<uint8_t> compressed1;
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    EncodeWithJpegli(input, jparams, &cinfo);
    compressed0.assign(buffer, buffer + buffer_size);
    jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
    EncodeWithJpegli(input, jparams, &cinfo);
    compressed1.assign(buffer, buffer + buffer_size);
    return true;
  };
  EXPECT_TRUE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
  ASSERT_EQ(compressed0.size(), compressed1.size());
  EXPECT_EQ(0,
            memcmp(compressed0.data(), compressed1.data(), compressed0.size()));
}

std::vector<TestConfig> GenerateBasicConfigs() {
  std::vector<TestConfig> all_configs;
  for (int samp : {1, 2}) {
    for (int progr : {0, 2}) {
      for (int optimize : {0, 1}) {
        if (progr && optimize) continue;
        TestConfig config;
        config.input.xsize = 257 + samp * 37;
        config.input.ysize = 265 + optimize * 17;
        config.jparams.h_sampling = {samp, 1, 1};
        config.jparams.v_sampling = {samp, 1, 1};
        config.jparams.progressive_mode = progr;
        config.jparams.optimize_coding = optimize;
        config.max_dist = 2.4f;
        GeneratePixels(&config.input);
        all_configs.push_back(config);
      }
    }
  }
  return all_configs;
}

TEST(EncodeAPITest, ReuseCinfoSameMemOutput) {
  std::vector<TestConfig> all_configs = GenerateBasicConfigs();
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  {
    jpeg_compress_struct cinfo;
    const auto try_catch_block = [&]() -> bool {
      ERROR_HANDLER_SETUP(jpegli);
      jpegli_create_compress(&cinfo);
      jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
      for (const TestConfig& config : all_configs) {
        EncodeWithJpegli(config.input, config.jparams, &cinfo);
      }
      return true;
    };
    EXPECT_TRUE(try_catch_block());
    jpegli_destroy_compress(&cinfo);
  }
  size_t pos = 0;
  for (size_t i = 0; i < all_configs.size(); ++i) {
    TestImage output;
    pos +=
        DecodeWithLibjpeg(all_configs[i].jparams, DecompressParams(), nullptr,
                          0, buffer + pos, buffer_size - pos, &output);
    VerifyOutputImage(all_configs[i].input, output, all_configs[i].max_dist);
  }
  if (buffer) free(buffer);
}

TEST(EncodeAPITest, ReuseCinfoSameStdOutput) {
  std::vector<TestConfig> all_configs = GenerateBasicConfigs();
  FILE* tmpf = tmpfile();
  JXL_CHECK(tmpf);
  {
    jpeg_compress_struct cinfo;
    const auto try_catch_block = [&]() -> bool {
      ERROR_HANDLER_SETUP(jpegli);
      jpegli_create_compress(&cinfo);
      jpegli_stdio_dest(&cinfo, tmpf);
      for (const TestConfig& config : all_configs) {
        EncodeWithJpegli(config.input, config.jparams, &cinfo);
      }
      return true;
    };
    EXPECT_TRUE(try_catch_block());
    jpegli_destroy_compress(&cinfo);
  }
  size_t total_size = ftell(tmpf);
  rewind(tmpf);
  std::vector<uint8_t> compressed(total_size);
  JXL_CHECK(total_size == fread(&compressed[0], 1, total_size, tmpf));
  fclose(tmpf);
  size_t pos = 0;
  for (size_t i = 0; i < all_configs.size(); ++i) {
    TestImage output;
    pos += DecodeWithLibjpeg(all_configs[i].jparams, DecompressParams(),
                             nullptr, 0, &compressed[pos],
                             compressed.size() - pos, &output);
    VerifyOutputImage(all_configs[i].input, output, all_configs[i].max_dist);
  }
}

TEST(EncodeAPITest, ReuseCinfoChangeParams) {
  TestImage input, output;
  CompressParams jparams;
  DecompressParams dparams;
  uint8_t* buffer = nullptr;
  unsigned long buffer_size = 0;
  std::vector<uint8_t> compressed;
  jpeg_compress_struct cinfo;
  const auto max_rms = [](int q, int hs, int vs) {
    if (hs == 1 && vs == 1) return q == 90 ? 2.2 : 0.6;
    if (hs == 2 && vs == 2) return q == 90 ? 2.8 : 1.2;
    return q == 90 ? 2.4 : 1.0;
  };
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    input.xsize = 129;
    input.ysize = 73;
    dparams.set_out_color_space = true;
    for (JpegIOMode input_mode : {PIXELS, RAW_DATA, PIXELS, COEFFICIENTS}) {
      for (int h_samp : {2, 1}) {
        for (int v_samp : {2, 1}) {
          for (int progr : {0, 2}) {
            for (int quality : {90, 100}) {
              input.Clear();
              input.color_space =
                  (input_mode == RAW_DATA ? JCS_YCbCr : JCS_RGB);
              jparams.quality = quality;
              jparams.h_sampling = {h_samp, 1, 1};
              jparams.v_sampling = {v_samp, 1, 1};
              jparams.progressive_mode = progr;
              printf(
                  "Generating input with quality %d chroma subsampling %dx%d "
                  "input mode %d progressive_mode %d\n",
                  quality, h_samp, v_samp, input_mode, progr);
              GenerateInput(input_mode, jparams, &input);
              jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
              if (input_mode != COEFFICIENTS) {
                cinfo.image_width = input.xsize;
                cinfo.image_height = input.ysize;
                cinfo.input_components = input.components;
                jpegli_set_defaults(&cinfo);
                jpegli_start_compress(&cinfo, TRUE);
                jpegli_abort_compress(&cinfo);
                jpegli_mem_dest(&cinfo, &buffer, &buffer_size);
              }
              EncodeWithJpegli(input, jparams, &cinfo);
              compressed.resize(buffer_size);
              std::copy_n(buffer, buffer_size, compressed.data());
              dparams.output_mode =
                  input_mode == COEFFICIENTS ? COEFFICIENTS : PIXELS;
              dparams.out_color_space = input.color_space;
              output.Clear();
              DecodeWithLibjpeg(jparams, dparams, compressed, &output);
              VerifyOutputImage(input, output,
                                max_rms(quality, h_samp, v_samp));
            }
          }
        }
      }
    }
    return true;
  };
  EXPECT_TRUE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  if (buffer) free(buffer);
}

TEST(EncodeAPITest, AbbreviatedStreams) {
  uint8_t* table_stream = nullptr;
  unsigned long table_stream_size = 0;
  uint8_t* data_stream = nullptr;
  unsigned long data_stream_size = 0;
  {
    jpeg_compress_struct cinfo;
    const auto try_catch_block = [&]() -> bool {
      ERROR_HANDLER_SETUP(jpegli);
      jpegli_create_compress(&cinfo);
      jpegli_mem_dest(&cinfo, &table_stream, &table_stream_size);
      cinfo.input_components = 3;
      cinfo.in_color_space = JCS_RGB;
      jpegli_set_defaults(&cinfo);
      jpegli_write_tables(&cinfo);
      jpegli_mem_dest(&cinfo, &data_stream, &data_stream_size);
      cinfo.image_width = 1;
      cinfo.image_height = 1;
      cinfo.optimize_coding = FALSE;
      jpegli_set_progressive_level(&cinfo, 0);
      jpegli_start_compress(&cinfo, FALSE);
      JSAMPLE image[3] = {0};
      JSAMPROW row[] = {image};
      jpegli_write_scanlines(&cinfo, row, 1);
      jpegli_finish_compress(&cinfo);
      return true;
    };
    EXPECT_TRUE(try_catch_block());
    EXPECT_LT(data_stream_size, 50);
    jpegli_destroy_compress(&cinfo);
  }
  TestImage output;
  DecodeWithLibjpeg(CompressParams(), DecompressParams(), table_stream,
                    table_stream_size, data_stream, data_stream_size, &output);
  EXPECT_EQ(1, output.xsize);
  EXPECT_EQ(1, output.ysize);
  EXPECT_EQ(3, output.components);
  EXPECT_EQ(0, output.pixels[0]);
  EXPECT_EQ(0, output.pixels[1]);
  EXPECT_EQ(0, output.pixels[2]);
  if (table_stream) free(table_stream);
  if (data_stream) free(data_stream);
}

void CopyQuantTables(j_compress_ptr cinfo, uint16_t* quant_tables) {
  for (int c = 0; c < cinfo->num_components; ++c) {
    int quant_idx = cinfo->comp_info[c].quant_tbl_no;
    JQUANT_TBL* quant_table = cinfo->quant_tbl_ptrs[quant_idx];
    for (int k = 0; k < DCTSIZE2; ++k) {
      quant_tables[c * DCTSIZE2 + k] = quant_table->quantval[k];
    }
  }
}

TEST(EncodeAPITest, QualitySettings) {
  // Test that jpegli_set_quality, jpegli_set_linear_quality and
  // jpegli_quality_scaling are consistent with each other.
  uint16_t quant_tables0[3 * DCTSIZE2];
  uint16_t quant_tables1[3 * DCTSIZE2];
  jpeg_compress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    cinfo.input_components = 3;
    cinfo.in_color_space = JCS_RGB;
    jpegli_set_defaults(&cinfo);
    for (boolean baseline : {FALSE, TRUE}) {
      for (int q = 1; q <= 100; ++q) {
        jpegli_set_quality(&cinfo, q, baseline);
        CopyQuantTables(&cinfo, quant_tables0);
        jpegli_set_linear_quality(&cinfo, jpegli_quality_scaling(q), baseline);
        CopyQuantTables(&cinfo, quant_tables1);
        EXPECT_EQ(0,
                  memcmp(quant_tables0, quant_tables1, sizeof(quant_tables0)));
#if JPEG_LIB_VERSION >= 70
        for (int i = 0; i < NUM_QUANT_TBLS; ++i) {
          cinfo.q_scale_factor[i] = jpegli_quality_scaling(q);
        }
        jpegli_default_qtables(&cinfo, baseline);
        CopyQuantTables(&cinfo, quant_tables1);
        EXPECT_EQ(0,
                  memcmp(quant_tables0, quant_tables1, sizeof(quant_tables0)));
#endif
      }
    }
    return true;
  };
  EXPECT_TRUE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  // Test jpegli_quality_scaling for some specific values .
  EXPECT_EQ(5000, jpegli_quality_scaling(-1));
  EXPECT_EQ(5000, jpegli_quality_scaling(0));
  EXPECT_EQ(5000, jpegli_quality_scaling(1));
  EXPECT_EQ(100, jpegli_quality_scaling(50));
  EXPECT_EQ(50, jpegli_quality_scaling(75));
  EXPECT_EQ(20, jpegli_quality_scaling(90));
  EXPECT_EQ(0, jpegli_quality_scaling(100));
  EXPECT_EQ(0, jpegli_quality_scaling(101));
}

std::vector<TestConfig> GenerateTests() {
  std::vector<TestConfig> all_tests;
  for (int h_samp : {1, 2}) {
    for (int v_samp : {1, 2}) {
      for (int progr : {0, 2}) {
        for (int optimize : {0, 1}) {
          if (progr && optimize) continue;
          TestConfig config;
          config.jparams.h_sampling = {h_samp, 1, 1};
          config.jparams.v_sampling = {v_samp, 1, 1};
          config.jparams.progressive_mode = progr;
          if (!progr) {
            config.jparams.optimize_coding = optimize;
          }
          const float kMaxBpp[4] = {1.55, 1.4, 1.4, 1.32};
          const float kMaxDist[4] = {1.95, 2.2, 2.2, 2.0};
          const int idx = v_samp * 2 + h_samp - 3;
          config.max_bpp =
              kMaxBpp[idx] * (optimize ? 0.97 : 1.0) * (progr ? 0.97 : 1.0);
          config.max_dist = kMaxDist[idx];
          all_tests.push_back(config);
        }
      }
    }
  }
  {
    TestConfig config;
    config.jparams.quality = 100;
    config.max_bpp = 6.6;
    config.max_dist = 0.6;
    all_tests.push_back(config);
  }
  {
    TestConfig config;
    config.jparams.quality = 80;
    config.max_bpp = 1.05;
    config.max_dist = 2.7;
    all_tests.push_back(config);
  }
  for (int samp : {1, 2}) {
    for (int progr : {0, 2}) {
      for (int optimize : {0, 1}) {
        if (progr && optimize) continue;
        TestConfig config;
        config.input.xsize = 257;
        config.input.ysize = 265;
        config.jparams.h_sampling = {samp, 1, 1};
        config.jparams.v_sampling = {samp, 1, 1};
        config.jparams.progressive_mode = progr;
        if (!progr) {
          config.jparams.optimize_coding = optimize;
        }
        config.jparams.use_adaptive_quantization = false;
        config.max_bpp = 2.05f;
        config.max_dist = 2.3f;
        all_tests.push_back(config);
      }
    }
  }
  for (int h0_samp : {1, 2, 4}) {
    for (int v0_samp : {1, 2, 4}) {
      for (int h2_samp : {1, 2, 4}) {
        for (int v2_samp : {1, 2, 4}) {
          TestConfig config;
          config.input.xsize = 137;
          config.input.ysize = 75;
          config.jparams.progressive_mode = 2;
          config.jparams.h_sampling = {h0_samp, 1, h2_samp};
          config.jparams.v_sampling = {v0_samp, 1, v2_samp};
          config.max_bpp = 2.5;
          config.max_dist = 12.0;
          all_tests.push_back(config);
        }
      }
    }
  }
  for (int h0_samp : {1, 3}) {
    for (int v0_samp : {1, 3}) {
      for (int h2_samp : {1, 3}) {
        for (int v2_samp : {1, 3}) {
          TestConfig config;
          config.input.xsize = 205;
          config.input.ysize = 99;
          config.jparams.progressive_mode = 2;
          config.jparams.h_sampling = {h0_samp, 1, h2_samp};
          config.jparams.v_sampling = {v0_samp, 1, v2_samp};
          config.max_bpp = 2.5;
          config.max_dist = 10.0;
          all_tests.push_back(config);
        }
      }
    }
  }
  for (int h0_samp : {1, 2, 3, 4}) {
    for (int v0_samp : {1, 2, 3, 4}) {
      TestConfig config;
      config.input.xsize = 217;
      config.input.ysize = 129;
      config.jparams.progressive_mode = 2;
      config.jparams.h_sampling = {h0_samp, 1, 1};
      config.jparams.v_sampling = {v0_samp, 1, 1};
      config.max_bpp = 2.0;
      config.max_dist = 5.5;
      all_tests.push_back(config);
    }
  }
  for (int p = 0; p < 3 + NumTestScanScripts(); ++p) {
    for (int samp : {1, 2}) {
      for (int quality : {100, 90, 1}) {
        for (int r : {0, 1024, 1}) {
          for (int optimize : {0, 1}) {
            bool progressive = p == 1 || p == 2 || p > 4;
            if (progressive && !optimize) continue;
            TestConfig config;
            config.input.xsize = 273;
            config.input.ysize = 265;
            config.jparams.progressive_mode = p;
            if (!progressive) {
              config.jparams.optimize_coding = optimize;
            }
            config.jparams.h_sampling = {samp, 1, 1};
            config.jparams.v_sampling = {samp, 1, 1};
            config.jparams.quality = quality;
            config.jparams.restart_interval = r;
            config.max_bpp = quality == 100 ? 8.0 : 1.9;
            if (r == 1) {
              config.max_bpp += 10.0;
            }
            config.max_dist = quality == 1 ? 20.0 : 2.1;
            all_tests.push_back(config);
          }
        }
      }
    }
  }
  {
    TestConfig config;
    config.jparams.simple_progression = true;
    config.max_bpp = 1.48;
    config.max_dist = 2.0;
    all_tests.push_back(config);
  }
  {
    TestConfig config;
    config.input_mode = COEFFICIENTS;
    config.jparams.h_sampling = {2, 1, 1};
    config.jparams.v_sampling = {2, 1, 1};
    config.jparams.progressive_mode = 0;
    config.jparams.optimize_coding = 0;
    config.max_bpp = 16;
    config.max_dist = 0.0;
    all_tests.push_back(config);
  }
  {
    TestConfig config;
    config.jparams.xyb_mode = true;
    config.jparams.progressive_mode = 2;
    config.max_bpp = 1.5;
    config.max_dist = 3.5;
    all_tests.push_back(config);
  }
  {
    TestConfig config;
    config.jparams.libjpeg_mode = true;
    config.max_bpp = 2.1;
    config.max_dist = 1.7;
    all_tests.push_back(config);
  }

  for (J_COLOR_SPACE in_color_space : {JCS_RGB, JCS_YCbCr, JCS_GRAYSCALE}) {
    for (J_COLOR_SPACE jpeg_color_space : {JCS_RGB, JCS_YCbCr, JCS_GRAYSCALE}) {
      if (jpeg_color_space == JCS_RGB && in_color_space == JCS_YCbCr) continue;
      TestConfig config;
      config.input.xsize = config.input.ysize = 256;
      config.input.color_space = in_color_space;
      config.jparams.set_jpeg_colorspace = true;
      config.jparams.jpeg_color_space = jpeg_color_space;
      config.max_bpp = jpeg_color_space == JCS_RGB ? 4.5 : 1.85;
      config.max_dist = jpeg_color_space == JCS_RGB ? 1.4 : 2.05;
      all_tests.push_back(config);
    }
  }
  for (J_COLOR_SPACE in_color_space : {JCS_CMYK, JCS_YCCK}) {
    for (J_COLOR_SPACE jpeg_color_space : {JCS_CMYK, JCS_YCCK}) {
      if (jpeg_color_space == JCS_CMYK && in_color_space == JCS_YCCK) continue;
      TestConfig config;
      config.input.xsize = config.input.ysize = 256;
      config.input.color_space = in_color_space;
      if (in_color_space != jpeg_color_space) {
        config.jparams.set_jpeg_colorspace = true;
        config.jparams.jpeg_color_space = jpeg_color_space;
      }
      config.max_bpp = jpeg_color_space == JCS_CMYK ? 4.0 : 3.6;
      config.max_dist = jpeg_color_space == JCS_CMYK ? 1.2 : 1.5;
      all_tests.push_back(config);
    }
  }
  {
    TestConfig config;
    config.input.color_space = JCS_YCbCr;
    config.max_bpp = 1.6;
    config.max_dist = 1.35;
    all_tests.push_back(config);
  }
  for (bool xyb : {false, true}) {
    TestConfig config;
    config.input.color_space = JCS_GRAYSCALE;
    config.jparams.xyb_mode = xyb;
    config.max_bpp = 1.35;
    config.max_dist = 1.4;
    all_tests.push_back(config);
  }
  for (int channels = 1; channels <= 4; ++channels) {
    TestConfig config;
    config.input.color_space = JCS_UNKNOWN;
    config.input.components = channels;
    config.max_bpp = 1.35 * channels;
    config.max_dist = 1.4;
    all_tests.push_back(config);
  }
  for (size_t r : {1, 3, 17, 1024}) {
    for (int progr : {0, 2}) {
      TestConfig config;
      config.jparams.restart_interval = r;
      config.jparams.progressive_mode = progr;
      config.max_bpp = 1.58 + 5.5 / r;
      config.max_dist = 2.2;
      all_tests.push_back(config);
    }
  }
  for (size_t rr : {1, 3, 8, 100}) {
    TestConfig config;
    config.jparams.restart_in_rows = rr;
    config.max_bpp = 1.6;
    config.max_dist = 2.2;
    all_tests.push_back(config);
  }
  for (int type : {0, 1, 10, 100, 10000}) {
    for (int scale : {1, 50, 100, 200, 500}) {
      for (bool add_raw : {false, true}) {
        for (bool baseline : {true, false}) {
          if (!baseline && (add_raw || type * scale < 25500)) continue;
          TestConfig config;
          config.input.xsize = 64;
          config.input.ysize = 64;
          CustomQuantTable table;
          table.table_type = type;
          table.scale_factor = scale;
          table.force_baseline = baseline;
          table.add_raw = add_raw;
          table.Generate();
          config.jparams.optimize_coding = 1;
          config.jparams.quant_tables.push_back(table);
          config.jparams.quant_indexes = {0, 0, 0};
          float q = (type == 0 ? 16 : type) * scale * 0.01f;
          if (baseline && !add_raw) q = std::max(1.0f, std::min(255.0f, q));
          config.max_bpp = 1.5f + 25.0f / q;
          config.max_dist = 0.6f + 0.25f * q;
          all_tests.push_back(config);
        }
      }
    }
  }
  for (int qidx = 0; qidx < 8; ++qidx) {
    if (qidx == 3) continue;
    TestConfig config;
    config.input.xsize = 256;
    config.input.ysize = 256;
    config.jparams.quant_indexes = {(qidx >> 2) & 1, (qidx >> 1) & 1,
                                    (qidx >> 0) & 1};
    config.max_bpp = 2.25;
    config.max_dist = 2.8;
    all_tests.push_back(config);
  }
  for (int qidx = 0; qidx < 8; ++qidx) {
    for (int slot_idx = 0; slot_idx < 2; ++slot_idx) {
      if (qidx == 0 && slot_idx == 0) continue;
      TestConfig config;
      config.input.xsize = 256;
      config.input.ysize = 256;
      config.jparams.quant_indexes = {(qidx >> 2) & 1, (qidx >> 1) & 1,
                                      (qidx >> 0) & 1};
      CustomQuantTable table;
      table.slot_idx = slot_idx;
      table.Generate();
      config.jparams.quant_tables.push_back(table);
      config.max_bpp = 2.3;
      config.max_dist = 2.9;
      all_tests.push_back(config);
    }
  }
  for (int qidx = 0; qidx < 8; ++qidx) {
    for (bool xyb : {false, true}) {
      TestConfig config;
      config.input.xsize = 256;
      config.input.ysize = 256;
      config.jparams.xyb_mode = xyb;
      config.jparams.quant_indexes = {(qidx >> 2) & 1, (qidx >> 1) & 1,
                                      (qidx >> 0) & 1};
      {
        CustomQuantTable table;
        table.slot_idx = 0;
        table.Generate();
        config.jparams.quant_tables.push_back(table);
      }
      {
        CustomQuantTable table;
        table.slot_idx = 1;
        table.table_type = 20;
        table.Generate();
        config.jparams.quant_tables.push_back(table);
      }
      config.max_bpp = 2.0;
      config.max_dist = 3.85;
      all_tests.push_back(config);
    }
  }
  for (bool xyb : {false, true}) {
    TestConfig config;
    config.input.xsize = 256;
    config.input.ysize = 256;
    config.jparams.xyb_mode = xyb;
    config.jparams.quant_indexes = {0, 1, 2};
    {
      CustomQuantTable table;
      table.slot_idx = 0;
      table.Generate();
      config.jparams.quant_tables.push_back(table);
    }
    {
      CustomQuantTable table;
      table.slot_idx = 1;
      table.table_type = 20;
      table.Generate();
      config.jparams.quant_tables.push_back(table);
    }
    {
      CustomQuantTable table;
      table.slot_idx = 2;
      table.table_type = 30;
      table.Generate();
      config.jparams.quant_tables.push_back(table);
    }
    config.max_bpp = 1.5;
    config.max_dist = 3.75;
    all_tests.push_back(config);
  }
  {
    TestConfig config;
    config.jparams.comp_ids = {7, 17, 177};
    config.input.xsize = config.input.ysize = 128;
    config.max_bpp = 2.25;
    config.max_dist = 2.4;
    all_tests.push_back(config);
  }
  for (int override_JFIF : {-1, 0, 1}) {
    for (int override_Adobe : {-1, 0, 1}) {
      if (override_JFIF == -1 && override_Adobe == -1) continue;
      TestConfig config;
      config.input.xsize = config.input.ysize = 128;
      config.jparams.override_JFIF = override_JFIF;
      config.jparams.override_Adobe = override_Adobe;
      config.max_bpp = 2.25;
      config.max_dist = 2.4;
      all_tests.push_back(config);
    }
  }
  {
    TestConfig config;
    config.input.xsize = config.input.ysize = 256;
    config.max_bpp = 1.85;
    config.max_dist = 2.05;
    config.jparams.add_marker = true;
    all_tests.push_back(config);
  }
  for (size_t icc_size : {728, 70000, 1000000}) {
    TestConfig config;
    config.input.xsize = config.input.ysize = 256;
    config.max_dist = 2.05;
    config.jparams.icc.resize(icc_size);
    for (size_t i = 0; i < icc_size; ++i) {
      config.jparams.icc[i] = (i * 17) & 0xff;
    }
    all_tests.push_back(config);
  }
  for (JpegIOMode input_mode : {PIXELS, RAW_DATA, COEFFICIENTS}) {
    TestConfig config;
    config.input.xsize = config.input.ysize = 256;
    config.input_mode = input_mode;
    if (input_mode == RAW_DATA) {
      config.input.color_space = JCS_YCbCr;
    }
    config.jparams.progressive_mode = 0;
    config.jparams.optimize_coding = 0;
    config.max_bpp = 1.85;
    config.max_dist = 2.05;
    if (input_mode == COEFFICIENTS) {
      config.max_bpp = 3.5;
      config.max_dist = 0.0;
    }
    all_tests.push_back(config);
    config.jparams.use_flat_dc_luma_code = true;
    all_tests.push_back(config);
  }
  for (int xsize : {640, 641, 648, 649}) {
    for (int ysize : {640, 641, 648, 649}) {
      for (int h_sampling : {1, 2}) {
        for (int v_sampling : {1, 2}) {
          if (h_sampling == 1 && v_sampling == 1) continue;
          for (int progr : {0, 2}) {
            TestConfig config;
            config.input.xsize = xsize;
            config.input.ysize = ysize;
            config.input.color_space = JCS_YCbCr;
            config.jparams.h_sampling = {h_sampling, 1, 1};
            config.jparams.v_sampling = {v_sampling, 1, 1};
            config.jparams.progressive_mode = progr;
            config.input_mode = RAW_DATA;
            config.max_bpp = 1.75;
            config.max_dist = 2.0;
            all_tests.push_back(config);
            config.input_mode = COEFFICIENTS;
            if (xsize & 1) {
              config.jparams.add_marker = true;
            }
            config.max_bpp = 24.0;
            all_tests.push_back(config);
          }
        }
      }
    }
  }
  for (JpegliDataType data_type : {JPEGLI_TYPE_UINT16, JPEGLI_TYPE_FLOAT}) {
    for (JpegliEndianness endianness :
         {JPEGLI_LITTLE_ENDIAN, JPEGLI_BIG_ENDIAN, JPEGLI_NATIVE_ENDIAN}) {
      J_COLOR_SPACE colorspace[4] = {JCS_GRAYSCALE, JCS_UNKNOWN, JCS_RGB,
                                     JCS_CMYK};
      float max_bpp[4] = {1.32, 2.7, 1.6, 4.0};
      for (int channels = 1; channels <= 4; ++channels) {
        TestConfig config;
        config.input.data_type = data_type;
        config.input.endianness = endianness;
        config.input.components = channels;
        config.input.color_space = colorspace[channels - 1];
        config.max_bpp = max_bpp[channels - 1];
        config.max_dist = 2.2;
        all_tests.push_back(config);
      }
    }
  }
  for (int smoothing : {1, 5, 50, 100}) {
    for (int h_sampling : {1, 2}) {
      for (int v_sampling : {1, 2}) {
        TestConfig config;
        config.input.xsize = 257;
        config.input.ysize = 265;
        config.jparams.smoothing_factor = smoothing;
        config.jparams.h_sampling = {h_sampling, 1, 1};
        config.jparams.v_sampling = {v_sampling, 1, 1};
        config.max_bpp = 1.85;
        config.max_dist = 3.05f;
        all_tests.push_back(config);
      }
    }
  }
  return all_tests;
};

std::ostream& operator<<(std::ostream& os, const TestConfig& c) {
  os << c.input;
  os << c.jparams;
  if (c.input_mode == RAW_DATA) {
    os << "RawDataIn";
  } else if (c.input_mode == COEFFICIENTS) {
    os << "WriteCoeffs";
  }
  return os;
}

std::string TestDescription(
    const testing::TestParamInfo<EncodeAPITestParam::ParamType>& info) {
  std::stringstream name;
  name << info.param;
  return name.str();
}

JPEGLI_INSTANTIATE_TEST_SUITE_P(EncodeAPITest, EncodeAPITestParam,
                                testing::ValuesIn(GenerateTests()),
                                TestDescription);
}  // namespace
}  // namespace jpegli
