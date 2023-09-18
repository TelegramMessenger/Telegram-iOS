// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/decode.h"
#include "lib/jpegli/encode.h"
#include "lib/jpegli/test_utils.h"
#include "lib/jpegli/testing.h"

namespace jpegli {
namespace {

// A simple suspending source manager with an input buffer.
struct SourceManager {
  jpeg_source_mgr pub;
  std::vector<uint8_t> buffer;

  SourceManager() {
    pub.next_input_byte = nullptr;
    pub.bytes_in_buffer = 0;
    pub.init_source = init_source;
    pub.fill_input_buffer = fill_input_buffer;
    pub.skip_input_data = skip_input_data;
    pub.resync_to_restart = jpegli_resync_to_restart;
    pub.term_source = term_source;
  }

  static void init_source(j_decompress_ptr cinfo) {}
  static boolean fill_input_buffer(j_decompress_ptr cinfo) { return FALSE; }
  static void skip_input_data(j_decompress_ptr cinfo, long num_bytes) {}
  static void term_source(j_decompress_ptr cinfo) {}
};

// A destination manager that empties its output buffer into a SourceManager's
// input buffer. The buffer size is kept short because empty_output_buffer() is
// called only when the output buffer is full, and we want to update the decoder
// input frequently to demostrate that streaming works.
static constexpr size_t kOutputBufferSize = 1024;
struct DestinationManager {
  jpeg_destination_mgr pub;
  std::vector<uint8_t> buffer;
  SourceManager* dest;

  DestinationManager(SourceManager* src)
      : buffer(kOutputBufferSize), dest(src) {
    pub.next_output_byte = buffer.data();
    pub.free_in_buffer = buffer.size();
    pub.init_destination = init_destination;
    pub.empty_output_buffer = empty_output_buffer;
    pub.term_destination = term_destination;
  }

  static void init_destination(j_compress_ptr cinfo) {}

  static boolean empty_output_buffer(j_compress_ptr cinfo) {
    auto us = reinterpret_cast<DestinationManager*>(cinfo->dest);
    jpeg_destination_mgr* src = &us->pub;
    jpeg_source_mgr* dst = &us->dest->pub;
    std::vector<uint8_t>& src_buf = us->buffer;
    std::vector<uint8_t>& dst_buf = us->dest->buffer;
    if (dst->bytes_in_buffer > 0 && dst->bytes_in_buffer < dst_buf.size()) {
      memmove(dst_buf.data(), dst->next_input_byte, dst->bytes_in_buffer);
    }
    size_t src_len = src_buf.size() - src->free_in_buffer;
    dst_buf.resize(dst->bytes_in_buffer + src_len);
    memcpy(&dst_buf[dst->bytes_in_buffer], src_buf.data(), src_len);
    dst->next_input_byte = dst_buf.data();
    dst->bytes_in_buffer = dst_buf.size();
    src->next_output_byte = src_buf.data();
    src->free_in_buffer = src_buf.size();
    return true;
  }

  static void term_destination(j_compress_ptr cinfo) {
    empty_output_buffer(cinfo);
  }
};

struct TestConfig {
  TestImage input;
  CompressParams jparams;
};

class StreamingTestParam : public ::testing::TestWithParam<TestConfig> {};

TEST_P(StreamingTestParam, TestStreaming) {
  jpeg_decompress_struct dinfo = {};
  jpeg_compress_struct cinfo = {};
  TestConfig config = GetParam();
  TestImage& input = config.input;
  TestImage output;
  GeneratePixels(&input);
  const auto try_catch_block = [&]() {
    ERROR_HANDLER_SETUP(jpegli);
    dinfo.err = cinfo.err;
    dinfo.client_data = cinfo.client_data;
    // Create a pair of compressor and decompressor objects, where the
    // compressor's output is connected to the decompressor's input.
    jpegli_create_decompress(&dinfo);
    jpegli_create_compress(&cinfo);
    SourceManager src;
    dinfo.src = reinterpret_cast<jpeg_source_mgr*>(&src);
    DestinationManager dest(&src);
    cinfo.dest = reinterpret_cast<jpeg_destination_mgr*>(&dest);

    cinfo.image_width = input.xsize;
    cinfo.image_height = input.ysize;
    cinfo.input_components = input.components;
    cinfo.in_color_space = (J_COLOR_SPACE)input.color_space;
    jpegli_set_defaults(&cinfo);
    cinfo.comp_info[0].v_samp_factor = config.jparams.v_sampling[0];
    jpegli_set_progressive_level(&cinfo, 0);
    cinfo.optimize_coding = FALSE;
    jpegli_start_compress(&cinfo, TRUE);

    size_t stride = cinfo.image_width * cinfo.input_components;
    size_t iMCU_height = 8 * cinfo.max_v_samp_factor;
    std::vector<uint8_t> row_bytes(iMCU_height * stride);
    size_t yin = 0;
    size_t yout = 0;
    while (yin < cinfo.image_height) {
      // Feed one iMCU row at a time to the compressor.
      size_t lines_in = std::min(iMCU_height, cinfo.image_height - yin);
      memcpy(&row_bytes[0], &input.pixels[yin * stride], lines_in * stride);
      std::vector<JSAMPROW> rows_in(lines_in);
      for (size_t i = 0; i < lines_in; ++i) {
        rows_in[i] = &row_bytes[i * stride];
      }
      EXPECT_EQ(lines_in,
                jpegli_write_scanlines(&cinfo, &rows_in[0], lines_in));
      yin += lines_in;
      if (yin == cinfo.image_height) {
        jpegli_finish_compress(&cinfo);
      }

      // Atfer the first iMCU row, we don't yet expect any output because the
      // compressor delays processing to have context rows after the iMCU row.
      if (yin < std::min<size_t>(2 * iMCU_height, cinfo.image_height)) {
        continue;
      }

      // After two iMCU rows, the compressor has started emitting compressed
      // data. We check here that at least the scan header was output, because
      // we expect that the compressor's output buffer was filled at least once
      // while emitting the first compressed iMCU row.
      if (yin == std::min<size_t>(2 * iMCU_height, cinfo.image_height)) {
        EXPECT_EQ(JPEG_REACHED_SOS,
                  jpegli_read_header(&dinfo, /*require_image=*/TRUE));
        output.xsize = dinfo.image_width;
        output.ysize = dinfo.image_height;
        output.components = dinfo.num_components;
        EXPECT_EQ(output.xsize, input.xsize);
        EXPECT_EQ(output.ysize, input.ysize);
        EXPECT_EQ(output.components, input.components);
        EXPECT_TRUE(jpegli_start_decompress(&dinfo));
        output.pixels.resize(output.ysize * stride);
        if (yin < cinfo.image_height) {
          continue;
        }
      }

      // After six iMCU rows, the compressor has emitted five iMCU rows of
      // compressed data, of which we expect four full iMCU row of compressed
      // data to be in the decoder's input buffer, but since the decoder also
      // needs context rows for upsampling and smoothing, we don't expect any
      // output to be ready yet.
      if (yin < 7 * iMCU_height && yin < cinfo.image_height) {
        continue;
      }

      // After five iMCU rows, we expect the decoder to have rendered the output
      // with four iMCU rows of delay.
      // TODO(szabadka) Reduce the processing delay in the decoder if possible.
      size_t lines_out =
          (yin == cinfo.image_height ? cinfo.image_height - yout : iMCU_height);
      std::vector<JSAMPROW> rows_out(lines_out);
      for (size_t i = 0; i < lines_out; ++i) {
        rows_out[i] =
            reinterpret_cast<JSAMPLE*>(&output.pixels[(yout + i) * stride]);
      }
      EXPECT_EQ(lines_out,
                jpegli_read_scanlines(&dinfo, &rows_out[0], lines_out));
      VerifyOutputImage(input, output, yout, lines_out, 3.8f);
      yout += lines_out;

      if (yout == cinfo.image_height) {
        EXPECT_TRUE(jpegli_finish_decompress(&dinfo));
      }
    }
    return true;
  };
  EXPECT_TRUE(try_catch_block());
  jpegli_destroy_decompress(&dinfo);
  jpegli_destroy_compress(&cinfo);
}

std::vector<TestConfig> GenerateTests() {
  std::vector<TestConfig> all_tests;
  const size_t xsize0 = 1920;
  const size_t ysize0 = 1080;
  for (int dysize : {0, 1, 8, 9}) {
    for (int v_sampling : {1, 2}) {
      TestConfig config;
      config.input.xsize = xsize0;
      config.input.ysize = ysize0 + dysize;
      config.jparams.h_sampling = {1, 1, 1};
      config.jparams.v_sampling = {v_sampling, 1, 1};
      all_tests.push_back(config);
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
    const testing::TestParamInfo<StreamingTestParam::ParamType>& info) {
  std::stringstream name;
  name << info.param;
  return name.str();
}

JPEGLI_INSTANTIATE_TEST_SUITE_P(StreamingTest, StreamingTestParam,
                                testing::ValuesIn(GenerateTests()),
                                TestDescription);

}  // namespace
}  // namespace jpegli
