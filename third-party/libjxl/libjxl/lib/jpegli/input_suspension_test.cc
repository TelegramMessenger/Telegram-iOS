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
#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/sanitizers.h"

namespace jpegli {
namespace {

static constexpr uint8_t kFakeEoiMarker[2] = {0xff, 0xd9};

struct SourceManager {
  SourceManager(const uint8_t* data, size_t len, size_t max_chunk_size,
                bool is_partial_file)
      : data_(data),
        len_(len),
        pos_(0),
        max_chunk_size_(max_chunk_size),
        is_partial_file_(is_partial_file) {
    pub_.init_source = init_source;
    pub_.fill_input_buffer = fill_input_buffer;
    pub_.next_input_byte = nullptr;
    pub_.bytes_in_buffer = 0;
    pub_.skip_input_data = skip_input_data;
    pub_.resync_to_restart = jpegli_resync_to_restart;
    pub_.term_source = term_source;
    if (max_chunk_size_ == 0) max_chunk_size_ = len;
  }

  ~SourceManager() {
    EXPECT_EQ(0, pub_.bytes_in_buffer);
    if (!is_partial_file_) {
      EXPECT_EQ(len_, pos_);
    }
  }

  bool LoadNextChunk() {
    if (pos_ >= len_ && !is_partial_file_) {
      return false;
    }
    if (pub_.bytes_in_buffer > 0) {
      EXPECT_LE(pub_.bytes_in_buffer, buffer_.size());
      memmove(&buffer_[0], pub_.next_input_byte, pub_.bytes_in_buffer);
    }
    size_t chunk_size =
        pos_ < len_ ? std::min(len_ - pos_, max_chunk_size_) : 2;
    buffer_.resize(pub_.bytes_in_buffer + chunk_size);
    memcpy(&buffer_[pub_.bytes_in_buffer],
           pos_ < len_ ? data_ + pos_ : kFakeEoiMarker, chunk_size);
    pub_.next_input_byte = &buffer_[0];
    pub_.bytes_in_buffer += chunk_size;
    pos_ += chunk_size;
    return true;
  }

 private:
  jpeg_source_mgr pub_;
  std::vector<uint8_t> buffer_;
  const uint8_t* data_;
  size_t len_;
  size_t pos_;
  size_t max_chunk_size_;
  bool is_partial_file_;

  static void init_source(j_decompress_ptr cinfo) {
    auto src = reinterpret_cast<SourceManager*>(cinfo->src);
    src->pub_.next_input_byte = nullptr;
    src->pub_.bytes_in_buffer = 0;
  }

  static boolean fill_input_buffer(j_decompress_ptr cinfo) { return FALSE; }

  static void skip_input_data(j_decompress_ptr cinfo, long num_bytes) {
    auto src = reinterpret_cast<SourceManager*>(cinfo->src);
    if (num_bytes <= 0) {
      return;
    }
    if (src->pub_.bytes_in_buffer >= static_cast<size_t>(num_bytes)) {
      src->pub_.bytes_in_buffer -= num_bytes;
      src->pub_.next_input_byte += num_bytes;
    } else {
      src->pos_ += num_bytes - src->pub_.bytes_in_buffer;
      src->pub_.bytes_in_buffer = 0;
    }
  }

  static void term_source(j_decompress_ptr cinfo) {}
};

uint8_t markers_seen[kMarkerSequenceLen];
size_t num_markers_seen = 0;

uint8_t get_next_byte(j_decompress_ptr cinfo) {
  cinfo->src->bytes_in_buffer--;
  return *cinfo->src->next_input_byte++;
}

boolean test_marker_processor(j_decompress_ptr cinfo) {
  markers_seen[num_markers_seen] = cinfo->unread_marker;
  if (cinfo->src->bytes_in_buffer < 2) {
    return FALSE;
  }
  size_t marker_len = (get_next_byte(cinfo) << 8) + get_next_byte(cinfo);
  EXPECT_EQ(2 + ((num_markers_seen + 2) % sizeof(kMarkerData)), marker_len);
  if (marker_len > 2) {
    (*cinfo->src->skip_input_data)(cinfo, marker_len - 2);
  }
  ++num_markers_seen;
  return TRUE;
}

void ReadOutputImage(const DecompressParams& dparams, j_decompress_ptr cinfo,
                     SourceManager* src, TestImage* output) {
  output->ysize = cinfo->output_height;
  output->xsize = cinfo->output_width;
  output->components = cinfo->num_components;
  if (cinfo->raw_data_out) {
    output->color_space = cinfo->jpeg_color_space;
    for (int c = 0; c < cinfo->num_components; ++c) {
      size_t xsize = cinfo->comp_info[c].width_in_blocks * DCTSIZE;
      size_t ysize = cinfo->comp_info[c].height_in_blocks * DCTSIZE;
      std::vector<uint8_t> plane(ysize * xsize);
      output->raw_data.emplace_back(std::move(plane));
    }
  } else {
    output->color_space = cinfo->out_color_space;
    output->AllocatePixels();
  }
  size_t total_output_lines = 0;
  while (cinfo->output_scanline < cinfo->output_height) {
    size_t max_lines;
    size_t num_output_lines;
    if (cinfo->raw_data_out) {
      size_t iMCU_height = cinfo->max_v_samp_factor * DCTSIZE;
      EXPECT_EQ(cinfo->output_scanline, cinfo->output_iMCU_row * iMCU_height);
      max_lines = iMCU_height;
      std::vector<std::vector<JSAMPROW>> rowdata(cinfo->num_components);
      std::vector<JSAMPARRAY> data(cinfo->num_components);
      for (int c = 0; c < cinfo->num_components; ++c) {
        size_t xsize = cinfo->comp_info[c].width_in_blocks * DCTSIZE;
        size_t ysize = cinfo->comp_info[c].height_in_blocks * DCTSIZE;
        size_t num_lines = cinfo->comp_info[c].v_samp_factor * DCTSIZE;
        rowdata[c].resize(num_lines);
        size_t y0 = cinfo->output_iMCU_row * num_lines;
        for (size_t i = 0; i < num_lines; ++i) {
          rowdata[c][i] =
              y0 + i < ysize ? &output->raw_data[c][(y0 + i) * xsize] : nullptr;
        }
        data[c] = &rowdata[c][0];
      }
      while ((num_output_lines =
                  jpegli_read_raw_data(cinfo, &data[0], max_lines)) == 0) {
        JXL_CHECK(src && src->LoadNextChunk());
      }
    } else {
      size_t max_output_lines = dparams.max_output_lines;
      if (max_output_lines == 0) max_output_lines = cinfo->output_height;
      size_t lines_left = cinfo->output_height - cinfo->output_scanline;
      max_lines = std::min<size_t>(max_output_lines, lines_left);
      size_t stride = cinfo->output_width * cinfo->num_components;
      std::vector<JSAMPROW> scanlines(max_lines);
      for (size_t i = 0; i < max_lines; ++i) {
        size_t yidx = cinfo->output_scanline + i;
        scanlines[i] = &output->pixels[yidx * stride];
      }
      while ((num_output_lines = jpegli_read_scanlines(cinfo, &scanlines[0],
                                                       max_lines)) == 0) {
        JXL_CHECK(src && src->LoadNextChunk());
      }
    }
    total_output_lines += num_output_lines;
    EXPECT_EQ(total_output_lines, cinfo->output_scanline);
    if (num_output_lines < max_lines) {
      JXL_CHECK(src && src->LoadNextChunk());
    }
  }
}

struct TestConfig {
  std::string fn;
  std::string fn_desc;
  TestImage input;
  CompressParams jparams;
  DecompressParams dparams;
  float max_rms_dist = 1.0f;
};

std::vector<uint8_t> GetTestJpegData(TestConfig& config) {
  if (!config.fn.empty()) {
    return ReadTestData(config.fn.c_str());
  }
  GeneratePixels(&config.input);
  std::vector<uint8_t> compressed;
  JXL_CHECK(EncodeWithJpegli(config.input, config.jparams, &compressed));
  return compressed;
}

bool IsSequential(const TestConfig& config) {
  if (!config.fn.empty()) {
    return config.fn_desc.find("PROGR") == std::string::npos;
  }
  return config.jparams.progressive_mode <= 0;
}

class InputSuspensionTestParam : public ::testing::TestWithParam<TestConfig> {};

TEST_P(InputSuspensionTestParam, InputOutputLockStepNonBuffered) {
  TestConfig config = GetParam();
  const DecompressParams& dparams = config.dparams;
  std::vector<uint8_t> compressed = GetTestJpegData(config);
  bool is_partial = config.dparams.size_factor < 1.0f;
  if (is_partial) {
    compressed.resize(compressed.size() * config.dparams.size_factor);
  }
  SourceManager src(compressed.data(), compressed.size(), dparams.chunk_size,
                    is_partial);
  TestImage output0;
  jpeg_decompress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    cinfo.src = reinterpret_cast<jpeg_source_mgr*>(&src);

    if (config.jparams.add_marker) {
      jpegli_save_markers(&cinfo, kSpecialMarker0, 0xffff);
      jpegli_save_markers(&cinfo, kSpecialMarker1, 0xffff);
      num_markers_seen = 0;
      jpegli_set_marker_processor(&cinfo, 0xe6, test_marker_processor);
      jpegli_set_marker_processor(&cinfo, 0xe7, test_marker_processor);
      jpegli_set_marker_processor(&cinfo, 0xe8, test_marker_processor);
    }
    while (jpegli_read_header(&cinfo, TRUE) == JPEG_SUSPENDED) {
      JXL_CHECK(src.LoadNextChunk());
    }
    SetDecompressParams(dparams, &cinfo);
    jpegli_set_output_format(&cinfo, dparams.data_type, dparams.endianness);
    if (config.jparams.add_marker) {
      EXPECT_EQ(num_markers_seen, kMarkerSequenceLen);
      EXPECT_EQ(0, memcmp(markers_seen, kMarkerSequence, num_markers_seen));
    }
    VerifyHeader(config.jparams, &cinfo);
    cinfo.raw_data_out = dparams.output_mode == RAW_DATA;

    if (dparams.output_mode == COEFFICIENTS) {
      jvirt_barray_ptr* coef_arrays;
      while ((coef_arrays = jpegli_read_coefficients(&cinfo)) == nullptr) {
        JXL_CHECK(src.LoadNextChunk());
      }
      CopyCoefficients(&cinfo, coef_arrays, &output0);
    } else {
      while (!jpegli_start_decompress(&cinfo)) {
        JXL_CHECK(src.LoadNextChunk());
      }
      ReadOutputImage(dparams, &cinfo, &src, &output0);
    }

    while (!jpegli_finish_decompress(&cinfo)) {
      JXL_CHECK(src.LoadNextChunk());
    }
    return true;
  };
  ASSERT_TRUE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);

  TestImage output1;
  DecodeWithLibjpeg(config.jparams, dparams, compressed, &output1);
  VerifyOutputImage(output1, output0, config.max_rms_dist);
}

TEST_P(InputSuspensionTestParam, InputOutputLockStepBuffered) {
  TestConfig config = GetParam();
  if (config.jparams.add_marker) return;
  const DecompressParams& dparams = config.dparams;
  std::vector<uint8_t> compressed = GetTestJpegData(config);
  bool is_partial = config.dparams.size_factor < 1.0f;
  if (is_partial) {
    compressed.resize(compressed.size() * config.dparams.size_factor);
  }
  SourceManager src(compressed.data(), compressed.size(), dparams.chunk_size,
                    is_partial);
  std::vector<TestImage> output_progression0;
  jpeg_decompress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);

    cinfo.src = reinterpret_cast<jpeg_source_mgr*>(&src);

    while (jpegli_read_header(&cinfo, TRUE) == JPEG_SUSPENDED) {
      JXL_CHECK(src.LoadNextChunk());
    }
    SetDecompressParams(dparams, &cinfo);
    jpegli_set_output_format(&cinfo, dparams.data_type, dparams.endianness);

    cinfo.buffered_image = TRUE;
    cinfo.raw_data_out = dparams.output_mode == RAW_DATA;

    EXPECT_TRUE(jpegli_start_decompress(&cinfo));
    EXPECT_FALSE(jpegli_input_complete(&cinfo));
    EXPECT_EQ(0, cinfo.output_scan_number);

    int sos_marker_cnt = 1;  // read_header reads the first SOS marker
    while (!jpegli_input_complete(&cinfo)) {
      EXPECT_EQ(cinfo.input_scan_number, sos_marker_cnt);
      EXPECT_TRUE(jpegli_start_output(&cinfo, cinfo.input_scan_number));
      // start output sets output_scan_number, but does not change
      // input_scan_number
      EXPECT_EQ(cinfo.output_scan_number, cinfo.input_scan_number);
      EXPECT_EQ(cinfo.input_scan_number, sos_marker_cnt);
      TestImage output;
      ReadOutputImage(dparams, &cinfo, &src, &output);
      output_progression0.emplace_back(std::move(output));
      // read scanlines/read raw data does not change input/output scan number
      EXPECT_EQ(cinfo.input_scan_number, sos_marker_cnt);
      EXPECT_EQ(cinfo.output_scan_number, cinfo.input_scan_number);
      while (!jpegli_finish_output(&cinfo)) {
        JXL_CHECK(src.LoadNextChunk());
      }
      ++sos_marker_cnt;  // finish output reads the next SOS marker or EOI
      if (dparams.output_mode == COEFFICIENTS) {
        jvirt_barray_ptr* coef_arrays = jpegli_read_coefficients(&cinfo);
        JXL_CHECK(coef_arrays != nullptr);
        CopyCoefficients(&cinfo, coef_arrays, &output_progression0.back());
      }
    }

    EXPECT_TRUE(jpegli_finish_decompress(&cinfo));
    return true;
  };
  ASSERT_TRUE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);

  std::vector<TestImage> output_progression1;
  DecodeAllScansWithLibjpeg(config.jparams, dparams, compressed,
                            &output_progression1);
  ASSERT_EQ(output_progression0.size(), output_progression1.size());
  for (size_t i = 0; i < output_progression0.size(); ++i) {
    const TestImage& output = output_progression0[i];
    const TestImage& expected = output_progression1[i];
    VerifyOutputImage(expected, output, config.max_rms_dist);
  }
}

TEST_P(InputSuspensionTestParam, PreConsumeInputBuffered) {
  TestConfig config = GetParam();
  if (config.jparams.add_marker) return;
  const DecompressParams& dparams = config.dparams;
  std::vector<uint8_t> compressed = GetTestJpegData(config);
  bool is_partial = config.dparams.size_factor < 1.0f;
  if (is_partial) {
    compressed.resize(compressed.size() * config.dparams.size_factor);
  }
  std::vector<TestImage> output_progression1;
  DecodeAllScansWithLibjpeg(config.jparams, dparams, compressed,
                            &output_progression1);
  SourceManager src(compressed.data(), compressed.size(), dparams.chunk_size,
                    is_partial);
  TestImage output0;
  jpeg_decompress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    cinfo.src = reinterpret_cast<jpeg_source_mgr*>(&src);

    int status;
    while ((status = jpegli_consume_input(&cinfo)) != JPEG_REACHED_SOS) {
      if (status == JPEG_SUSPENDED) {
        JXL_CHECK(src.LoadNextChunk());
      }
    }
    EXPECT_EQ(JPEG_REACHED_SOS, jpegli_consume_input(&cinfo));
    cinfo.buffered_image = TRUE;
    cinfo.raw_data_out = dparams.output_mode == RAW_DATA;
    cinfo.do_block_smoothing = dparams.do_block_smoothing;

    EXPECT_TRUE(jpegli_start_decompress(&cinfo));
    EXPECT_FALSE(jpegli_input_complete(&cinfo));
    EXPECT_EQ(1, cinfo.input_scan_number);
    EXPECT_EQ(0, cinfo.output_scan_number);

    while ((status = jpegli_consume_input(&cinfo)) != JPEG_REACHED_EOI) {
      if (status == JPEG_SUSPENDED) {
        JXL_CHECK(src.LoadNextChunk());
      }
    }

    EXPECT_TRUE(jpegli_input_complete(&cinfo));
    EXPECT_EQ(output_progression1.size(), cinfo.input_scan_number);
    EXPECT_EQ(0, cinfo.output_scan_number);

    EXPECT_TRUE(jpegli_start_output(&cinfo, cinfo.input_scan_number));
    EXPECT_EQ(output_progression1.size(), cinfo.input_scan_number);
    EXPECT_EQ(cinfo.output_scan_number, cinfo.input_scan_number);

    ReadOutputImage(dparams, &cinfo, nullptr, &output0);
    EXPECT_EQ(output_progression1.size(), cinfo.input_scan_number);
    EXPECT_EQ(cinfo.output_scan_number, cinfo.input_scan_number);

    EXPECT_TRUE(jpegli_finish_output(&cinfo));
    if (dparams.output_mode == COEFFICIENTS) {
      jvirt_barray_ptr* coef_arrays = jpegli_read_coefficients(&cinfo);
      JXL_CHECK(coef_arrays != nullptr);
      CopyCoefficients(&cinfo, coef_arrays, &output0);
    }
    EXPECT_TRUE(jpegli_finish_decompress(&cinfo));
    return true;
  };
  ASSERT_TRUE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);

  VerifyOutputImage(output_progression1.back(), output0, config.max_rms_dist);
}

TEST_P(InputSuspensionTestParam, PreConsumeInputNonBuffered) {
  TestConfig config = GetParam();
  if (config.jparams.add_marker || IsSequential(config)) return;
  const DecompressParams& dparams = config.dparams;
  std::vector<uint8_t> compressed = GetTestJpegData(config);
  bool is_partial = config.dparams.size_factor < 1.0f;
  if (is_partial) {
    compressed.resize(compressed.size() * config.dparams.size_factor);
  }
  SourceManager src(compressed.data(), compressed.size(), dparams.chunk_size,
                    is_partial);
  TestImage output0;
  jpeg_decompress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    cinfo.src = reinterpret_cast<jpeg_source_mgr*>(&src);

    int status;
    while ((status = jpegli_consume_input(&cinfo)) != JPEG_REACHED_SOS) {
      if (status == JPEG_SUSPENDED) {
        JXL_CHECK(src.LoadNextChunk());
      }
    }
    EXPECT_EQ(JPEG_REACHED_SOS, jpegli_consume_input(&cinfo));
    cinfo.raw_data_out = dparams.output_mode == RAW_DATA;
    cinfo.do_block_smoothing = dparams.do_block_smoothing;

    if (dparams.output_mode == COEFFICIENTS) {
      jpegli_read_coefficients(&cinfo);
    } else {
      while (!jpegli_start_decompress(&cinfo)) {
        JXL_CHECK(src.LoadNextChunk());
      }
    }

    while ((status = jpegli_consume_input(&cinfo)) != JPEG_REACHED_EOI) {
      if (status == JPEG_SUSPENDED) {
        JXL_CHECK(src.LoadNextChunk());
      }
    }

    if (dparams.output_mode == COEFFICIENTS) {
      jvirt_barray_ptr* coef_arrays = jpegli_read_coefficients(&cinfo);
      JXL_CHECK(coef_arrays != nullptr);
      CopyCoefficients(&cinfo, coef_arrays, &output0);
    } else {
      ReadOutputImage(dparams, &cinfo, nullptr, &output0);
    }

    EXPECT_TRUE(jpegli_finish_decompress(&cinfo));
    return true;
  };
  ASSERT_TRUE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);

  TestImage output1;
  DecodeWithLibjpeg(config.jparams, dparams, compressed, &output1);
  VerifyOutputImage(output1, output0, config.max_rms_dist);
}

std::vector<TestConfig> GenerateTests() {
  std::vector<TestConfig> all_tests;
  std::vector<std::pair<std::string, std::string>> testfiles({
      {"jxl/flower/flower.png.im_q85_444.jpg", "Q85YUV444"},
      {"jxl/flower/flower.png.im_q85_420_R13B.jpg", "Q85YUV420R13B"},
      {"jxl/flower/flower.png.im_q85_420_progr.jpg", "Q85YUV420PROGR"},
  });
  for (const auto& it : testfiles) {
    for (size_t chunk_size : {1, 64, 65536}) {
      for (size_t max_output_lines : {0, 1, 8, 16}) {
        TestConfig config;
        config.fn = it.first;
        config.fn_desc = it.second;
        config.dparams.chunk_size = chunk_size;
        config.dparams.max_output_lines = max_output_lines;
        all_tests.push_back(config);
        if (max_output_lines == 16) {
          config.dparams.output_mode = RAW_DATA;
          all_tests.push_back(config);
          config.dparams.output_mode = COEFFICIENTS;
          all_tests.push_back(config);
        }
      }
    }
  }
  for (size_t r : {1, 17, 1024}) {
    for (size_t chunk_size : {1, 65536}) {
      TestConfig config;
      config.dparams.chunk_size = chunk_size;
      config.jparams.progressive_mode = 2;
      config.jparams.restart_interval = r;
      all_tests.push_back(config);
    }
  }
  for (size_t chunk_size : {1, 4, 1024}) {
    TestConfig config;
    config.input.xsize = 256;
    config.input.ysize = 256;
    config.dparams.chunk_size = chunk_size;
    config.jparams.add_marker = true;
    all_tests.push_back(config);
  }
  // Tests for partial input.
  for (float size_factor : {0.1f, 0.33f, 0.5f, 0.75f}) {
    for (int progr : {0, 1, 3}) {
      for (int samp : {1, 2}) {
        for (JpegIOMode output_mode : {PIXELS, RAW_DATA}) {
          TestConfig config;
          config.input.xsize = 517;
          config.input.ysize = 523;
          config.jparams.h_sampling = {samp, 1, 1};
          config.jparams.v_sampling = {samp, 1, 1};
          config.jparams.progressive_mode = progr;
          config.dparams.size_factor = size_factor;
          config.dparams.output_mode = output_mode;
          // The last partially available block can behave differently.
          // TODO(szabadka) Figure out if we can make the behaviour more
          // similar.
          config.max_rms_dist = samp == 1 ? 1.75f : 3.0f;
          all_tests.push_back(config);
        }
      }
    }
  }
  // Tests for block smoothing.
  for (float size_factor : {0.1f, 0.33f, 0.5f, 0.75f, 1.0f}) {
    for (int samp : {1, 2}) {
      TestConfig config;
      config.input.xsize = 517;
      config.input.ysize = 523;
      config.jparams.h_sampling = {samp, 1, 1};
      config.jparams.v_sampling = {samp, 1, 1};
      config.jparams.progressive_mode = 2;
      config.dparams.size_factor = size_factor;
      config.dparams.do_block_smoothing = true;
      // libjpeg does smoothing for incomplete scans differently at
      // the border between current and previous scans.
      config.max_rms_dist = 8.0f;
      all_tests.push_back(config);
    }
  }
  return all_tests;
}

std::ostream& operator<<(std::ostream& os, const TestConfig& c) {
  if (!c.fn.empty()) {
    os << c.fn_desc;
  } else {
    os << c.input;
  }
  os << c.jparams;
  if (c.dparams.chunk_size == 0) {
    os << "CompleteInput";
  } else {
    os << "InputChunks" << c.dparams.chunk_size;
  }
  if (c.dparams.size_factor < 1.0f) {
    os << "Partial" << static_cast<int>(c.dparams.size_factor * 100) << "p";
  }
  if (c.dparams.max_output_lines == 0) {
    os << "CompleteOutput";
  } else {
    os << "OutputLines" << c.dparams.max_output_lines;
  }
  if (c.dparams.output_mode == RAW_DATA) {
    os << "RawDataOut";
  } else if (c.dparams.output_mode == COEFFICIENTS) {
    os << "CoeffsOut";
  }
  if (c.dparams.do_block_smoothing) {
    os << "BlockSmoothing";
  }
  return os;
}

std::string TestDescription(
    const testing::TestParamInfo<InputSuspensionTestParam::ParamType>& info) {
  std::stringstream name;
  name << info.param;
  return name.str();
}

JPEGLI_INSTANTIATE_TEST_SUITE_P(InputSuspensionTest, InputSuspensionTestParam,
                                testing::ValuesIn(GenerateTests()),
                                TestDescription);

}  // namespace
}  // namespace jpegli
