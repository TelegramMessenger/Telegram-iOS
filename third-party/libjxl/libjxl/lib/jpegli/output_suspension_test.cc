// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/encode.h"
#include "lib/jpegli/test_utils.h"
#include "lib/jpegli/testing.h"

namespace jpegli {
namespace {

static constexpr size_t kInitialBufferSize = 1024;
static constexpr size_t kFinalBufferSize = 18;

struct DestinationManager {
  jpeg_destination_mgr pub;
  std::vector<uint8_t> buffer;

  DestinationManager() {
    pub.init_destination = init_destination;
    pub.empty_output_buffer = empty_output_buffer;
    pub.term_destination = term_destination;
  }

  void Rewind() {
    pub.next_output_byte = buffer.data();
    pub.free_in_buffer = buffer.size();
  }

  void EmptyTo(std::vector<uint8_t>* output, size_t new_size = 0) {
    output->insert(output->end(), buffer.data(), pub.next_output_byte);
    if (new_size > 0) {
      buffer.resize(new_size);
    }
    Rewind();
  }

  static void init_destination(j_compress_ptr cinfo) {
    auto us = reinterpret_cast<DestinationManager*>(cinfo->dest);
    us->buffer.resize(kInitialBufferSize);
    us->Rewind();
  }

  static boolean empty_output_buffer(j_compress_ptr cinfo) { return FALSE; }

  static void term_destination(j_compress_ptr cinfo) {}
};

struct TestConfig {
  TestImage input;
  CompressParams jparams;
  size_t buffer_size;
  size_t lines_batch_size;
};

class OutputSuspensionTestParam : public ::testing::TestWithParam<TestConfig> {
};

TEST_P(OutputSuspensionTestParam, PixelData) {
  jpeg_compress_struct cinfo = {};
  TestConfig config = GetParam();
  TestImage& input = config.input;
  GeneratePixels(&input);
  DestinationManager dest;
  std::vector<uint8_t> compressed;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    cinfo.dest = reinterpret_cast<jpeg_destination_mgr*>(&dest);

    cinfo.image_width = input.xsize;
    cinfo.image_height = input.ysize;
    cinfo.input_components = input.components;
    cinfo.in_color_space = JCS_RGB;
    jpegli_set_defaults(&cinfo);
    cinfo.comp_info[0].v_samp_factor = config.jparams.v_sampling[0];
    jpegli_set_progressive_level(&cinfo, 0);
    cinfo.optimize_coding = FALSE;
    jpegli_start_compress(&cinfo, TRUE);

    size_t stride = cinfo.image_width * cinfo.input_components;
    std::vector<uint8_t> row_bytes(config.lines_batch_size * stride);
    while (cinfo.next_scanline < cinfo.image_height) {
      size_t lines_left = cinfo.image_height - cinfo.next_scanline;
      size_t num_lines = std::min(config.lines_batch_size, lines_left);
      memcpy(&row_bytes[0], &input.pixels[cinfo.next_scanline * stride],
             num_lines * stride);
      std::vector<JSAMPROW> rows(num_lines);
      for (size_t i = 0; i < num_lines; ++i) {
        rows[i] = &row_bytes[i * stride];
      }
      size_t lines_done = 0;
      while (lines_done < num_lines) {
        lines_done += jpegli_write_scanlines(&cinfo, &rows[lines_done],
                                             num_lines - lines_done);
        if (lines_done < num_lines) {
          dest.EmptyTo(&compressed, config.buffer_size);
        }
      }
    }
    dest.EmptyTo(&compressed, kFinalBufferSize);
    jpegli_finish_compress(&cinfo);
    dest.EmptyTo(&compressed);
    return true;
  };
  ASSERT_TRUE(try_catch_block());
  jpegli_destroy_compress(&cinfo);
  TestImage output;
  DecodeWithLibjpeg(CompressParams(), DecompressParams(), compressed, &output);
  VerifyOutputImage(input, output, 2.5);
}

TEST_P(OutputSuspensionTestParam, RawData) {
  jpeg_compress_struct cinfo = {};
  TestConfig config = GetParam();
  if (config.lines_batch_size != 1) return;
  TestImage& input = config.input;
  input.color_space = JCS_YCbCr;
  GeneratePixels(&input);
  GenerateRawData(config.jparams, &input);
  DestinationManager dest;
  std::vector<uint8_t> compressed;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_compress(&cinfo);
    cinfo.dest = reinterpret_cast<jpeg_destination_mgr*>(&dest);
    cinfo.image_width = input.xsize;
    cinfo.image_height = input.ysize;
    cinfo.input_components = input.components;
    cinfo.in_color_space = JCS_YCbCr;
    jpegli_set_defaults(&cinfo);
    cinfo.comp_info[0].v_samp_factor = config.jparams.v_sampling[0];
    jpegli_set_progressive_level(&cinfo, 0);
    cinfo.optimize_coding = FALSE;
    cinfo.raw_data_in = TRUE;
    jpegli_start_compress(&cinfo, TRUE);

    std::vector<std::vector<uint8_t>> raw_data = input.raw_data;
    size_t max_lines = config.jparams.max_v_sample() * DCTSIZE;
    std::vector<std::vector<JSAMPROW>> rowdata(cinfo.num_components);
    std::vector<JSAMPARRAY> data(cinfo.num_components);
    for (int c = 0; c < cinfo.num_components; ++c) {
      rowdata[c].resize(config.jparams.v_samp(c) * DCTSIZE);
      data[c] = &rowdata[c][0];
    }
    while (cinfo.next_scanline < cinfo.image_height) {
      for (int c = 0; c < cinfo.num_components; ++c) {
        size_t cwidth = cinfo.comp_info[c].width_in_blocks * DCTSIZE;
        size_t cheight = cinfo.comp_info[c].height_in_blocks * DCTSIZE;
        size_t num_lines = config.jparams.v_samp(c) * DCTSIZE;
        size_t y0 = (cinfo.next_scanline / max_lines) * num_lines;
        for (size_t i = 0; i < num_lines; ++i) {
          rowdata[c][i] =
              (y0 + i < cheight ? &raw_data[c][(y0 + i) * cwidth] : nullptr);
        }
      }
      while (jpegli_write_raw_data(&cinfo, &data[0], max_lines) == 0) {
        dest.EmptyTo(&compressed, config.buffer_size);
      }
    }
    dest.EmptyTo(&compressed, kFinalBufferSize);
    jpegli_finish_compress(&cinfo);
    dest.EmptyTo(&compressed);
    return true;
  };
  try_catch_block();
  jpegli_destroy_compress(&cinfo);
  DecompressParams dparams;
  dparams.output_mode = RAW_DATA;
  TestImage output;
  DecodeWithLibjpeg(CompressParams(), dparams, compressed, &output);
  VerifyOutputImage(input, output, 3.5);
}

std::vector<TestConfig> GenerateTests() {
  std::vector<TestConfig> all_tests;
  const size_t xsize0 = 1920;
  const size_t ysize0 = 1080;
  for (int dysize : {0, 1, 8, 9}) {
    for (int v_sampling : {1, 2}) {
      for (int nlines : {1, 8, 117}) {
        for (int bufsize : {1, 16, 16 << 10}) {
          TestConfig config;
          config.lines_batch_size = nlines;
          config.buffer_size = bufsize;
          config.input.xsize = xsize0;
          config.input.ysize = ysize0 + dysize;
          config.jparams.h_sampling = {1, 1, 1};
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
  os << "Lines" << c.lines_batch_size;
  os << "BufSize" << c.buffer_size;
  return os;
}

std::string TestDescription(
    const testing::TestParamInfo<OutputSuspensionTestParam::ParamType>& info) {
  std::stringstream name;
  name << info.param;
  return name.str();
}

JPEGLI_INSTANTIATE_TEST_SUITE_P(OutputSuspensionTest, OutputSuspensionTestParam,
                                testing::ValuesIn(GenerateTests()),
                                TestDescription);

}  // namespace
}  // namespace jpegli
