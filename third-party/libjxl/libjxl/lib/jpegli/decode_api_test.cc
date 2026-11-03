// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>

#include <cmath>
#include <vector>

#include "lib/jpegli/decode.h"
#include "lib/jpegli/encode.h"
#include "lib/jpegli/test_utils.h"
#include "lib/jpegli/testing.h"
#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/sanitizers.h"

namespace jpegli {
namespace {

static constexpr uint8_t kFakeEoiMarker[2] = {0xff, 0xd9};
static constexpr size_t kNumSourceBuffers = 4;

// Custom source manager that refills the input buffer in chunks, simulating
// a file reader with a fixed buffer size.
class SourceManager {
 public:
  SourceManager(const uint8_t* data, size_t len, size_t max_chunk_size)
      : data_(data), len_(len), max_chunk_size_(max_chunk_size) {
    pub_.skip_input_data = skip_input_data;
    pub_.resync_to_restart = jpegli_resync_to_restart;
    pub_.term_source = term_source;
    pub_.init_source = init_source;
    pub_.fill_input_buffer = fill_input_buffer;
    if (max_chunk_size_ == 0) max_chunk_size_ = len;
    buffers_.resize(kNumSourceBuffers, std::vector<uint8_t>(max_chunk_size_));
    Reset();
  }

  void Reset() {
    pub_.next_input_byte = nullptr;
    pub_.bytes_in_buffer = 0;
    pos_ = 0;
    chunk_idx_ = 0;
  }

  ~SourceManager() {
    EXPECT_EQ(0, pub_.bytes_in_buffer);
    EXPECT_EQ(len_, pos_);
  }

 private:
  jpeg_source_mgr pub_;
  const uint8_t* data_;
  size_t len_;
  size_t chunk_idx_;
  size_t pos_;
  size_t max_chunk_size_;
  std::vector<std::vector<uint8_t>> buffers_;

  static void init_source(j_decompress_ptr cinfo) {}

  static boolean fill_input_buffer(j_decompress_ptr cinfo) {
    auto src = reinterpret_cast<SourceManager*>(cinfo->src);
    if (src->pos_ < src->len_) {
      size_t chunk_size = std::min(src->len_ - src->pos_, src->max_chunk_size_);
      size_t next_idx = ++src->chunk_idx_ % kNumSourceBuffers;
      uint8_t* next_buffer = src->buffers_[next_idx].data();
      memcpy(next_buffer, src->data_ + src->pos_, chunk_size);
      src->pub_.next_input_byte = next_buffer;
      src->pub_.bytes_in_buffer = chunk_size;
    } else {
      src->pub_.next_input_byte = kFakeEoiMarker;
      src->pub_.bytes_in_buffer = 2;
      src->len_ += 2;
    }
    src->pos_ += src->pub_.bytes_in_buffer;
    return TRUE;
  }

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
  if (cinfo->src->bytes_in_buffer == 0) {
    (*cinfo->src->fill_input_buffer)(cinfo);
  }
  cinfo->src->bytes_in_buffer--;
  return *cinfo->src->next_input_byte++;
}

boolean test_marker_processor(j_decompress_ptr cinfo) {
  markers_seen[num_markers_seen] = cinfo->unread_marker;
  size_t marker_len = (get_next_byte(cinfo) << 8) + get_next_byte(cinfo);
  EXPECT_EQ(2 + ((num_markers_seen + 2) % sizeof(kMarkerData)), marker_len);
  if (marker_len > 2) {
    (*cinfo->src->skip_input_data)(cinfo, marker_len - 2);
  }
  ++num_markers_seen;
  return TRUE;
}

void ReadOutputImage(const DecompressParams& dparams, j_decompress_ptr cinfo,
                     TestImage* output) {
  JDIMENSION xoffset = 0;
  JDIMENSION yoffset = 0;
  JDIMENSION xsize_cropped = cinfo->output_width;
  JDIMENSION ysize_cropped = cinfo->output_height;
  if (dparams.crop_output) {
    xoffset = xsize_cropped = cinfo->output_width / 3;
    yoffset = ysize_cropped = cinfo->output_height / 3;
    jpegli_crop_scanline(cinfo, &xoffset, &xsize_cropped);
  }
  output->ysize = ysize_cropped;
  output->xsize = cinfo->output_width;
  output->components = cinfo->out_color_components;
  output->data_type = dparams.data_type;
  output->endianness = dparams.endianness;
  size_t bytes_per_sample = jpegli_bytes_per_sample(dparams.data_type);
  if (cinfo->raw_data_out) {
    output->color_space = cinfo->jpeg_color_space;
    for (int c = 0; c < cinfo->num_components; ++c) {
      size_t xsize = cinfo->comp_info[c].width_in_blocks * DCTSIZE;
      size_t ysize = cinfo->comp_info[c].height_in_blocks * DCTSIZE;
      std::vector<uint8_t> plane(ysize * xsize * bytes_per_sample);
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
      num_output_lines = jpegli_read_raw_data(cinfo, &data[0], max_lines);
    } else {
      size_t max_output_lines = dparams.max_output_lines;
      if (max_output_lines == 0) max_output_lines = cinfo->output_height;
      if (cinfo->output_scanline < yoffset) {
        max_lines = yoffset - cinfo->output_scanline;
        num_output_lines = jpegli_skip_scanlines(cinfo, max_lines);
      } else if (cinfo->output_scanline >= yoffset + ysize_cropped) {
        max_lines = cinfo->output_height - cinfo->output_scanline;
        num_output_lines = jpegli_skip_scanlines(cinfo, max_lines);
      } else {
        size_t lines_left = yoffset + ysize_cropped - cinfo->output_scanline;
        max_lines = std::min<size_t>(max_output_lines, lines_left);
        size_t stride = cinfo->output_width * cinfo->out_color_components *
                        bytes_per_sample;
        std::vector<JSAMPROW> scanlines(max_lines);
        for (size_t i = 0; i < max_lines; ++i) {
          size_t yidx = cinfo->output_scanline - yoffset + i;
          scanlines[i] = &output->pixels[yidx * stride];
        }
        num_output_lines =
            jpegli_read_scanlines(cinfo, &scanlines[0], max_lines);
        if (cinfo->quantize_colors) {
          for (size_t i = 0; i < num_output_lines; ++i) {
            UnmapColors(scanlines[i], cinfo->output_width,
                        cinfo->out_color_components, cinfo->colormap,
                        cinfo->actual_number_of_colors);
          }
        }
      }
    }
    total_output_lines += num_output_lines;
    EXPECT_EQ(total_output_lines, cinfo->output_scanline);
    EXPECT_EQ(num_output_lines, max_lines);
  }
  EXPECT_EQ(cinfo->total_iMCU_rows,
            DivCeil(cinfo->image_height, cinfo->max_v_samp_factor * DCTSIZE));
}

struct TestConfig {
  std::string fn;
  std::string fn_desc;
  TestImage input;
  CompressParams jparams;
  DecompressParams dparams;
  bool compare_to_orig = false;
  float max_tolerance_factor = 1.01f;
  float max_rms_dist = 1.0f;
  float max_diff = 35.0f;
};

std::vector<uint8_t> GetTestJpegData(TestConfig& config) {
  std::vector<uint8_t> compressed;
  if (!config.fn.empty()) {
    compressed = ReadTestData(config.fn.c_str());
  } else {
    GeneratePixels(&config.input);
    JXL_CHECK(EncodeWithJpegli(config.input, config.jparams, &compressed));
  }
  if (config.dparams.size_factor < 1.0f) {
    compressed.resize(compressed.size() * config.dparams.size_factor);
  }
  return compressed;
}

void TestAPINonBuffered(const CompressParams& jparams,
                        const DecompressParams& dparams,
                        const TestImage& expected_output,
                        j_decompress_ptr cinfo, TestImage* output) {
  if (jparams.add_marker) {
    jpegli_save_markers(cinfo, kSpecialMarker0, 0xffff);
    jpegli_save_markers(cinfo, kSpecialMarker1, 0xffff);
    num_markers_seen = 0;
    jpegli_set_marker_processor(cinfo, 0xe6, test_marker_processor);
    jpegli_set_marker_processor(cinfo, 0xe7, test_marker_processor);
    jpegli_set_marker_processor(cinfo, 0xe8, test_marker_processor);
  }
  if (!jparams.icc.empty()) {
    jpegli_save_markers(cinfo, JPEG_APP0 + 2, 0xffff);
  }
  jpegli_read_header(cinfo, /*require_image=*/TRUE);
  if (jparams.add_marker) {
    EXPECT_EQ(num_markers_seen, kMarkerSequenceLen);
    EXPECT_EQ(0, memcmp(markers_seen, kMarkerSequence, num_markers_seen));
  }
  if (!jparams.icc.empty()) {
    uint8_t* icc_data = nullptr;
    unsigned int icc_len;
    JXL_CHECK(jpegli_read_icc_profile(cinfo, &icc_data, &icc_len));
    JXL_CHECK(icc_data);
    EXPECT_EQ(0, memcmp(jparams.icc.data(), icc_data, icc_len));
    free(icc_data);
  }
  // Check that jpegli_calc_output_dimensions can be called multiple times
  // even with different parameters.
  if (!cinfo->raw_data_out) {
    cinfo->scale_num = 1;
    cinfo->scale_denom = 2;
  }
  jpegli_calc_output_dimensions(cinfo);
  SetDecompressParams(dparams, cinfo);
  jpegli_set_output_format(cinfo, dparams.data_type, dparams.endianness);
  VerifyHeader(jparams, cinfo);
  jpegli_calc_output_dimensions(cinfo);
  EXPECT_LE(expected_output.xsize, cinfo->output_width);
  if (!dparams.crop_output) {
    EXPECT_EQ(expected_output.xsize, cinfo->output_width);
  }
  if (dparams.output_mode == COEFFICIENTS) {
    jvirt_barray_ptr* coef_arrays = jpegli_read_coefficients(cinfo);
    JXL_CHECK(coef_arrays != nullptr);
    CopyCoefficients(cinfo, coef_arrays, output);
  } else {
    jpegli_start_decompress(cinfo);
    VerifyScanHeader(jparams, cinfo);
    ReadOutputImage(dparams, cinfo, output);
  }
  jpegli_finish_decompress(cinfo);
}

void TestAPIBuffered(const CompressParams& jparams,
                     const DecompressParams& dparams, j_decompress_ptr cinfo,
                     std::vector<TestImage>* output_progression) {
  EXPECT_EQ(JPEG_REACHED_SOS,
            jpegli_read_header(cinfo, /*require_image=*/TRUE));
  cinfo->buffered_image = TRUE;
  SetDecompressParams(dparams, cinfo);
  jpegli_set_output_format(cinfo, dparams.data_type, dparams.endianness);
  VerifyHeader(jparams, cinfo);
  EXPECT_TRUE(jpegli_start_decompress(cinfo));
  // start decompress should not read the whole input in buffered image mode
  EXPECT_FALSE(jpegli_input_complete(cinfo));
  bool has_multiple_scans = jpegli_has_multiple_scans(cinfo);
  EXPECT_EQ(0, cinfo->output_scan_number);
  int sos_marker_cnt = 1;  // read_header reads the first SOS marker
  while (!jpegli_input_complete(cinfo)) {
    EXPECT_EQ(cinfo->input_scan_number, sos_marker_cnt);
    if (dparams.skip_scans && (cinfo->input_scan_number % 2) != 1) {
      int result = JPEG_SUSPENDED;
      while (result != JPEG_REACHED_SOS && result != JPEG_REACHED_EOI) {
        result = jpegli_consume_input(cinfo);
      }
      if (result == JPEG_REACHED_SOS) ++sos_marker_cnt;
      continue;
    }
    SetScanDecompressParams(dparams, cinfo, cinfo->input_scan_number);
    EXPECT_TRUE(jpegli_start_output(cinfo, cinfo->input_scan_number));
    // start output sets output_scan_number, but does not change
    // input_scan_number
    EXPECT_EQ(cinfo->output_scan_number, cinfo->input_scan_number);
    EXPECT_EQ(cinfo->input_scan_number, sos_marker_cnt);
    VerifyScanHeader(jparams, cinfo);
    TestImage output;
    ReadOutputImage(dparams, cinfo, &output);
    output_progression->emplace_back(std::move(output));
    // read scanlines/read raw data does not change input/output scan number
    EXPECT_EQ(cinfo->input_scan_number, sos_marker_cnt);
    EXPECT_EQ(cinfo->output_scan_number, cinfo->input_scan_number);
    EXPECT_TRUE(jpegli_finish_output(cinfo));
    ++sos_marker_cnt;  // finish output reads the next SOS marker or EOI
    if (dparams.output_mode == COEFFICIENTS) {
      jvirt_barray_ptr* coef_arrays = jpegli_read_coefficients(cinfo);
      JXL_CHECK(coef_arrays != nullptr);
      CopyCoefficients(cinfo, coef_arrays, &output_progression->back());
    }
  }
  jpegli_finish_decompress(cinfo);
  if (dparams.size_factor == 1.0f) {
    EXPECT_EQ(has_multiple_scans, cinfo->input_scan_number > 1);
  }
}

TEST(DecodeAPITest, ReuseCinfo) {
  TestImage input, output, expected;
  std::vector<TestImage> output_progression, expected_output_progression;
  CompressParams jparams;
  DecompressParams dparams;
  std::vector<uint8_t> compressed;
  jpeg_decompress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    input.xsize = 129;
    input.ysize = 73;
    GeneratePixels(&input);
    for (int h_samp : {2, 1}) {
      for (int v_samp : {2, 1}) {
        for (int progr : {0, 2}) {
          jparams.h_sampling = {h_samp, 1, 1};
          jparams.v_sampling = {v_samp, 1, 1};
          jparams.progressive_mode = progr;
          printf(
              "Generating input with %dx%d chroma subsampling "
              "progressive level %d\n",
              h_samp, v_samp, progr);
          JXL_CHECK(EncodeWithJpegli(input, jparams, &compressed));
          for (JpegIOMode output_mode : {PIXELS, RAW_DATA, COEFFICIENTS}) {
            for (bool crop : {true, false}) {
              if (crop && output_mode != PIXELS) continue;
              for (int scale_num : {1, 2, 3, 4, 7, 8, 13, 16}) {
                if (scale_num != 8 && output_mode != PIXELS) continue;
                int scale_denom = 8;
                while (scale_num % 2 == 0 && scale_denom % 2 == 0) {
                  scale_num /= 2;
                  scale_denom /= 2;
                }
                printf("Decoding with output mode %d output scaling %d/%d %s\n",
                       output_mode, scale_num, scale_denom,
                       crop ? "with cropped output" : "");
                dparams.output_mode = output_mode;
                dparams.scale_num = scale_num;
                dparams.scale_denom = scale_denom;
                expected.Clear();
                DecodeWithLibjpeg(jparams, dparams, compressed, &expected);
                output.Clear();
                cinfo.buffered_image = false;
                cinfo.raw_data_out = false;
                cinfo.scale_num = cinfo.scale_denom = 1;
                SourceManager src(compressed.data(), compressed.size(),
                                  1u << 12);
                cinfo.src = reinterpret_cast<jpeg_source_mgr*>(&src);
                jpegli_read_header(&cinfo, /*require_image=*/TRUE);
                jpegli_abort_decompress(&cinfo);
                src.Reset();
                TestAPINonBuffered(jparams, dparams, expected, &cinfo, &output);
                float max_rms = output_mode == COEFFICIENTS ? 0.0f : 1.0f;
                if (scale_num == 1 && scale_denom == 8 && h_samp != v_samp) {
                  max_rms = 5.0f;  // libjpeg does not do fancy upsampling
                }
                VerifyOutputImage(expected, output, max_rms);
                printf("Decoding in buffered image mode\n");
                expected_output_progression.clear();
                DecodeAllScansWithLibjpeg(jparams, dparams, compressed,
                                          &expected_output_progression);
                output_progression.clear();
                src.Reset();
                TestAPIBuffered(jparams, dparams, &cinfo, &output_progression);
                JXL_CHECK(output_progression.size() ==
                          expected_output_progression.size());
                for (size_t i = 0; i < output_progression.size(); ++i) {
                  const TestImage& output = output_progression[i];
                  const TestImage& expected = expected_output_progression[i];
                  VerifyOutputImage(expected, output, max_rms);
                }
              }
            }
          }
        }
      }
    }
    return true;
  };
  ASSERT_TRUE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);
}

std::vector<TestConfig> GenerateBasicConfigs() {
  std::vector<TestConfig> all_configs;
  for (int samp : {1, 2}) {
    for (int progr : {0, 2}) {
      TestConfig config;
      config.input.xsize = 257 + samp * 37;
      config.input.ysize = 265 + (progr / 2) * 17;
      config.jparams.h_sampling = {samp, 1, 1};
      config.jparams.v_sampling = {samp, 1, 1};
      config.jparams.progressive_mode = progr;
      GeneratePixels(&config.input);
      all_configs.push_back(config);
    }
  }
  return all_configs;
}

TEST(DecodeAPITest, ReuseCinfoSameMemSource) {
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
  std::vector<TestImage> all_outputs(all_configs.size());
  {
    jpeg_decompress_struct cinfo;
    const auto try_catch_block = [&]() -> bool {
      ERROR_HANDLER_SETUP(jpegli);
      jpegli_create_decompress(&cinfo);
      jpegli_mem_src(&cinfo, buffer, buffer_size);
      for (size_t i = 0; i < all_configs.size(); ++i) {
        TestAPINonBuffered(all_configs[i].jparams, DecompressParams(),
                           all_configs[i].input, &cinfo, &all_outputs[i]);
      }
      return true;
    };
    EXPECT_TRUE(try_catch_block());
    jpegli_destroy_decompress(&cinfo);
  }
  for (size_t i = 0; i < all_configs.size(); ++i) {
    VerifyOutputImage(all_configs[i].input, all_outputs[i], 2.35f);
  }
  if (buffer) free(buffer);
}

TEST(DecodeAPITest, ReuseCinfoSameStdSource) {
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
  rewind(tmpf);
  std::vector<TestImage> all_outputs(all_configs.size());
  {
    jpeg_decompress_struct cinfo;
    const auto try_catch_block = [&]() -> bool {
      ERROR_HANDLER_SETUP(jpegli);
      jpegli_create_decompress(&cinfo);
      jpegli_stdio_src(&cinfo, tmpf);
      for (size_t i = 0; i < all_configs.size(); ++i) {
        TestAPINonBuffered(all_configs[i].jparams, DecompressParams(),
                           all_configs[i].input, &cinfo, &all_outputs[i]);
      }
      return true;
    };
    EXPECT_TRUE(try_catch_block());
    jpegli_destroy_decompress(&cinfo);
  }
  for (size_t i = 0; i < all_configs.size(); ++i) {
    VerifyOutputImage(all_configs[i].input, all_outputs[i], 2.35f);
  }
  fclose(tmpf);
}

TEST(DecodeAPITest, AbbreviatedStreams) {
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
  {
    jpeg_decompress_struct cinfo = {};
    const auto try_catch_block = [&]() -> bool {
      ERROR_HANDLER_SETUP(jpegli);
      jpegli_create_decompress(&cinfo);
      jpegli_mem_src(&cinfo, table_stream, table_stream_size);
      jpegli_read_header(&cinfo, FALSE);
      jpegli_mem_src(&cinfo, data_stream, data_stream_size);
      jpegli_read_header(&cinfo, TRUE);
      EXPECT_EQ(1, cinfo.image_width);
      EXPECT_EQ(1, cinfo.image_height);
      EXPECT_EQ(3, cinfo.num_components);
      jpegli_start_decompress(&cinfo);
      JSAMPLE image[3] = {0};
      JSAMPROW row[] = {image};
      jpegli_read_scanlines(&cinfo, row, 1);
      EXPECT_EQ(0, image[0]);
      EXPECT_EQ(0, image[1]);
      EXPECT_EQ(0, image[2]);
      jpegli_finish_decompress(&cinfo);
      return true;
    };
    EXPECT_TRUE(try_catch_block());
    jpegli_destroy_decompress(&cinfo);
  }
  if (table_stream) free(table_stream);
  if (data_stream) free(data_stream);
}

class DecodeAPITestParam : public ::testing::TestWithParam<TestConfig> {};

TEST_P(DecodeAPITestParam, TestAPI) {
  TestConfig config = GetParam();
  const DecompressParams& dparams = config.dparams;
  if (dparams.skip_scans) return;
  const std::vector<uint8_t> compressed = GetTestJpegData(config);
  SourceManager src(compressed.data(), compressed.size(), dparams.chunk_size);

  TestImage output1;
  DecodeWithLibjpeg(config.jparams, dparams, compressed, &output1);

  TestImage output0;
  jpeg_decompress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    cinfo.src = reinterpret_cast<jpeg_source_mgr*>(&src);
    TestAPINonBuffered(config.jparams, dparams, output1, &cinfo, &output0);
    return true;
  };
  ASSERT_TRUE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);

  if (config.compare_to_orig) {
    double rms0 = DistanceRms(config.input, output0);
    double rms1 = DistanceRms(config.input, output1);
    printf("rms: %f  vs  %f\n", rms0, rms1);
    EXPECT_LE(rms0, rms1 * config.max_tolerance_factor);
  } else {
    VerifyOutputImage(output0, output1, config.max_rms_dist, config.max_diff);
  }
}

class DecodeAPITestParamBuffered : public ::testing::TestWithParam<TestConfig> {
};

TEST_P(DecodeAPITestParamBuffered, TestAPI) {
  TestConfig config = GetParam();
  const DecompressParams& dparams = config.dparams;
  const std::vector<uint8_t> compressed = GetTestJpegData(config);
  SourceManager src(compressed.data(), compressed.size(), dparams.chunk_size);

  std::vector<TestImage> output_progression1;
  DecodeAllScansWithLibjpeg(config.jparams, dparams, compressed,
                            &output_progression1);

  std::vector<TestImage> output_progression0;
  jpeg_decompress_struct cinfo;
  const auto try_catch_block = [&]() -> bool {
    ERROR_HANDLER_SETUP(jpegli);
    jpegli_create_decompress(&cinfo);
    cinfo.src = reinterpret_cast<jpeg_source_mgr*>(&src);
    TestAPIBuffered(config.jparams, dparams, &cinfo, &output_progression0);
    return true;
  };
  ASSERT_TRUE(try_catch_block());
  jpegli_destroy_decompress(&cinfo);

  ASSERT_EQ(output_progression0.size(), output_progression1.size());
  for (size_t i = 0; i < output_progression0.size(); ++i) {
    const TestImage& output = output_progression0[i];
    const TestImage& expected = output_progression1[i];
    if (config.compare_to_orig) {
      double rms0 = DistanceRms(config.input, output);
      double rms1 = DistanceRms(config.input, expected);
      printf("rms: %f  vs  %f\n", rms0, rms1);
      EXPECT_LE(rms0, rms1 * config.max_tolerance_factor);
    } else {
      VerifyOutputImage(expected, output, config.max_rms_dist, config.max_diff);
    }
  }
}

std::vector<TestConfig> GenerateTests(bool buffered) {
  std::vector<TestConfig> all_tests;
  {
    std::vector<std::pair<std::string, std::string>> testfiles({
        {"jxl/flower/flower.png.im_q85_420_progr.jpg", "Q85YUV420PROGR"},
        {"jxl/flower/flower.png.im_q85_420_R13B.jpg", "Q85YUV420R13B"},
        {"jxl/flower/flower.png.im_q85_444.jpg", "Q85YUV444"},
    });
    for (size_t i = 0; i < (buffered ? 1u : testfiles.size()); ++i) {
      TestConfig config;
      config.fn = testfiles[i].first;
      config.fn_desc = testfiles[i].second;
      for (size_t chunk_size : {0, 1, 64, 65536}) {
        config.dparams.chunk_size = chunk_size;
        for (size_t max_output_lines : {0, 1, 8, 16}) {
          config.dparams.max_output_lines = max_output_lines;
          config.dparams.output_mode = PIXELS;
          all_tests.push_back(config);
        }
        {
          config.dparams.max_output_lines = 16;
          config.dparams.output_mode = RAW_DATA;
          all_tests.push_back(config);
        }
      }
    }
  }

  {
    std::vector<std::pair<std::string, std::string>> testfiles({
        {"jxl/flower/flower_small.q85_444_non_interleaved.jpg",
         "Q85YUV444NonInterleaved"},
        {"jxl/flower/flower_small.q85_420_non_interleaved.jpg",
         "Q85YUV420NonInterleaved"},
        {"jxl/flower/flower_small.q85_444_partially_interleaved.jpg",
         "Q85YUV444PartiallyInterleaved"},
        {"jxl/flower/flower_small.q85_420_partially_interleaved.jpg",
         "Q85YUV420PartiallyInterleaved"},
        {"jxl/flower/flower.png.im_q85_422.jpg", "Q85YUV422"},
        {"jxl/flower/flower.png.im_q85_440.jpg", "Q85YUV440"},
        {"jxl/flower/flower.png.im_q85_444_1x2.jpg", "Q85YUV444_1x2"},
        {"jxl/flower/flower.png.im_q85_asymmetric.jpg", "Q85Asymmetric"},
        {"jxl/flower/flower.png.im_q85_gray.jpg", "Q85Gray"},
        {"jxl/flower/flower.png.im_q85_luma_subsample.jpg", "Q85LumaSubsample"},
        {"jxl/flower/flower.png.im_q85_rgb.jpg", "Q85RGB"},
        {"jxl/flower/flower.png.im_q85_rgb_subsample_blue.jpg",
         "Q85RGBSubsampleBlue"},
        {"jxl/flower/flower_small.cmyk.jpg", "CMYK"},
    });
    for (size_t i = 0; i < (buffered ? 4u : testfiles.size()); ++i) {
      for (JpegIOMode output_mode : {PIXELS, RAW_DATA}) {
        TestConfig config;
        config.fn = testfiles[i].first;
        config.fn_desc = testfiles[i].second;
        config.dparams.output_mode = output_mode;
        all_tests.push_back(config);
      }
    }
  }

  // Tests for common chroma subsampling and output modes.
  for (JpegIOMode output_mode : {PIXELS, RAW_DATA, COEFFICIENTS}) {
    for (int h_samp : {1, 2}) {
      for (int v_samp : {1, 2}) {
        for (bool fancy : {true, false}) {
          if (!fancy && (output_mode != PIXELS || h_samp * v_samp == 1)) {
            continue;
          }
          TestConfig config;
          config.dparams.output_mode = output_mode;
          config.dparams.do_fancy_upsampling = fancy;
          config.jparams.progressive_mode = 2;
          config.jparams.h_sampling = {h_samp, 1, 1};
          config.jparams.v_sampling = {v_samp, 1, 1};
          if (output_mode == COEFFICIENTS) {
            config.max_rms_dist = 0.0f;
          }
          all_tests.push_back(config);
        }
      }
    }
  }

  // Tests for partial input.
  for (float size_factor : {0.1f, 0.33f, 0.5f, 0.75f}) {
    for (int progr : {0, 1, 3}) {
      for (int samp : {1, 2}) {
        for (bool skip_scans : {false, true}) {
          if (skip_scans && (progr != 1 || size_factor < 0.5f)) continue;
          for (JpegIOMode output_mode : {PIXELS, RAW_DATA}) {
            TestConfig config;
            config.input.xsize = 517;
            config.input.ysize = 523;
            config.jparams.h_sampling = {samp, 1, 1};
            config.jparams.v_sampling = {samp, 1, 1};
            config.jparams.progressive_mode = progr;
            config.dparams.size_factor = size_factor;
            config.dparams.output_mode = output_mode;
            config.dparams.skip_scans = skip_scans;
            // The last partially available block can behave differently.
            // TODO(szabadka) Figure out if we can make the behaviour more
            // similar.
            config.max_rms_dist = samp == 1 ? 1.75f : 3.0f;
            config.max_diff = 255.0f;
            all_tests.push_back(config);
          }
        }
      }
    }
  }

  // Tests for block smoothing.
  for (float size_factor : {0.1f, 0.33f, 0.5f, 0.75f, 1.0f}) {
    for (int samp : {1, 2}) {
      for (bool skip_scans : {false, true}) {
        if (skip_scans && size_factor < 0.3f) continue;
        TestConfig config;
        config.input.xsize = 517;
        config.input.ysize = 523;
        config.jparams.h_sampling = {samp, 1, 1};
        config.jparams.v_sampling = {samp, 1, 1};
        config.jparams.progressive_mode = 2;
        config.dparams.size_factor = size_factor;
        config.dparams.do_block_smoothing = true;
        config.dparams.skip_scans = skip_scans;
        // libjpeg does smoothing for incomplete scans differently at
        // the border between current and previous scans.
        config.max_rms_dist = 8.0f;
        config.max_diff = 255.0f;
        all_tests.push_back(config);
      }
    }
  }

  // Test for switching output color quantization modes between scans.
  if (buffered) {
    TestConfig config;
    config.jparams.progressive_mode = 2;
    config.dparams.quantize_colors = true;
    config.dparams.scan_params = {
        {3, JDITHER_NONE, CQUANT_1PASS},  {4, JDITHER_ORDERED, CQUANT_1PASS},
        {5, JDITHER_FS, CQUANT_1PASS},    {6, JDITHER_NONE, CQUANT_EXTERNAL},
        {8, JDITHER_NONE, CQUANT_REUSE},  {9, JDITHER_NONE, CQUANT_EXTERNAL},
        {10, JDITHER_NONE, CQUANT_2PASS}, {11, JDITHER_NONE, CQUANT_REUSE},
        {12, JDITHER_NONE, CQUANT_2PASS}, {13, JDITHER_FS, CQUANT_2PASS},
    };
    config.compare_to_orig = true;
    config.max_tolerance_factor = 1.04f;
    all_tests.push_back(config);
  }

  if (buffered) {
    return all_tests;
  }

  // Tests for output color quantization.
  for (int num_colors : {8, 64, 256}) {
    for (ColorQuantMode mode : {CQUANT_1PASS, CQUANT_EXTERNAL, CQUANT_2PASS}) {
      if (mode == CQUANT_EXTERNAL && num_colors != 256) continue;
      for (J_DITHER_MODE dither : {JDITHER_NONE, JDITHER_ORDERED, JDITHER_FS}) {
        if (mode == CQUANT_EXTERNAL && dither != JDITHER_NONE) continue;
        if (mode != CQUANT_1PASS && dither == JDITHER_ORDERED) continue;
        for (bool crop : {false, true}) {
          for (bool scale : {false, true}) {
            for (bool samp : {false, true}) {
              if ((num_colors != 256) && (crop || scale || samp)) {
                continue;
              }
              if (mode == CQUANT_2PASS && crop) continue;
              TestConfig config;
              config.input.xsize = 1024;
              config.input.ysize = 768;
              config.dparams.quantize_colors = true;
              config.dparams.desired_number_of_colors = num_colors;
              config.dparams.scan_params = {{kLastScan, dither, mode}};
              config.dparams.crop_output = crop;
              if (scale) {
                config.dparams.scale_num = 7;
                config.dparams.scale_denom = 8;
              }
              if (samp) {
                config.jparams.h_sampling = {2, 1, 1};
                config.jparams.v_sampling = {2, 1, 1};
              }
              if (!scale && !crop) {
                config.compare_to_orig = true;
                if (dither != JDITHER_NONE) {
                  config.max_tolerance_factor = 1.05f;
                }
                if (mode == CQUANT_2PASS &&
                    (num_colors == 8 || dither == JDITHER_FS)) {
                  // TODO(szabadka) Lower this bound.
                  config.max_tolerance_factor = 1.5f;
                }
              } else {
                // We only test for buffer overflows, etc.
                config.max_rms_dist = 100.0f;
                config.max_diff = 255.0f;
              }
              all_tests.push_back(config);
            }
          }
        }
      }
    }
  }

  // Tests for output formats.
  for (JpegliDataType type :
       {JPEGLI_TYPE_UINT8, JPEGLI_TYPE_UINT16, JPEGLI_TYPE_FLOAT}) {
    for (JpegliEndianness endianness :
         {JPEGLI_NATIVE_ENDIAN, JPEGLI_LITTLE_ENDIAN, JPEGLI_BIG_ENDIAN}) {
      if (type == JPEGLI_TYPE_UINT8 && endianness != JPEGLI_NATIVE_ENDIAN) {
        continue;
      }
      for (int channels = 1; channels <= 4; ++channels) {
        TestConfig config;
        config.dparams.data_type = type;
        config.dparams.endianness = endianness;
        config.input.color_space = JCS_UNKNOWN;
        config.input.components = channels;
        config.dparams.set_out_color_space = true;
        config.dparams.out_color_space = JCS_UNKNOWN;
        all_tests.push_back(config);
      }
    }
  }
  // Test for output cropping.
  {
    TestConfig config;
    config.dparams.crop_output = true;
    all_tests.push_back(config);
  }
  // Tests for color transforms.
  for (J_COLOR_SPACE out_color_space : {JCS_RGB, JCS_GRAYSCALE}) {
    TestConfig config;
    config.input.xsize = config.input.ysize = 256;
    config.input.color_space = JCS_GRAYSCALE;
    config.dparams.set_out_color_space = true;
    config.dparams.out_color_space = out_color_space;
    all_tests.push_back(config);
  }
  for (J_COLOR_SPACE jpeg_color_space : {JCS_RGB, JCS_YCbCr}) {
    for (J_COLOR_SPACE out_color_space : {JCS_RGB, JCS_YCbCr, JCS_GRAYSCALE}) {
      if (jpeg_color_space == JCS_RGB && out_color_space == JCS_YCbCr) continue;
      TestConfig config;
      config.input.xsize = config.input.ysize = 256;
      config.jparams.set_jpeg_colorspace = true;
      config.jparams.jpeg_color_space = jpeg_color_space;
      config.dparams.set_out_color_space = true;
      config.dparams.out_color_space = out_color_space;
      all_tests.push_back(config);
    }
  }
  for (J_COLOR_SPACE jpeg_color_space : {JCS_CMYK, JCS_YCCK}) {
    for (J_COLOR_SPACE out_color_space : {JCS_CMYK, JCS_YCCK}) {
      if (jpeg_color_space == JCS_CMYK && out_color_space == JCS_YCCK) continue;
      TestConfig config;
      config.input.xsize = config.input.ysize = 256;
      config.input.color_space = JCS_CMYK;
      config.jparams.set_jpeg_colorspace = true;
      config.jparams.jpeg_color_space = jpeg_color_space;
      config.dparams.set_out_color_space = true;
      config.dparams.out_color_space = out_color_space;
      all_tests.push_back(config);
    }
  }
  // Tests for progressive levels.
  for (int p = 0; p < 3 + NumTestScanScripts(); ++p) {
    TestConfig config;
    config.jparams.progressive_mode = p;
    all_tests.push_back(config);
  }
  // Tests for RST markers.
  for (size_t r : {1, 17, 1024}) {
    for (size_t chunk_size : {1, 65536}) {
      for (int progr : {0, 2}) {
        TestConfig config;
        config.dparams.chunk_size = chunk_size;
        config.jparams.progressive_mode = progr;
        config.jparams.restart_interval = r;
        all_tests.push_back(config);
      }
    }
  }
  for (size_t rr : {1, 3, 8, 100}) {
    TestConfig config;
    config.jparams.restart_in_rows = rr;
    all_tests.push_back(config);
  }
  // Tests for custom quantization tables.
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
          config.jparams.quant_tables.push_back(table);
          config.jparams.quant_indexes = {0, 0, 0};
          config.compare_to_orig = true;
          config.max_tolerance_factor = 1.02;
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
      config.compare_to_orig = true;
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
    config.compare_to_orig = true;
    all_tests.push_back(config);
  }
  // Tests for fixed (and custom) prefix codes.
  for (J_COLOR_SPACE jpeg_color_space : {JCS_RGB, JCS_YCbCr}) {
    for (bool flat_dc_luma : {false, true}) {
      TestConfig config;
      config.jparams.set_jpeg_colorspace = true;
      config.jparams.jpeg_color_space = jpeg_color_space;
      config.jparams.progressive_mode = 0;
      config.jparams.optimize_coding = 0;
      config.jparams.use_flat_dc_luma_code = flat_dc_luma;
      all_tests.push_back(config);
    }
  }
  for (J_COLOR_SPACE jpeg_color_space : {JCS_CMYK, JCS_YCCK}) {
    for (bool flat_dc_luma : {false, true}) {
      TestConfig config;
      config.input.color_space = JCS_CMYK;
      config.jparams.set_jpeg_colorspace = true;
      config.jparams.jpeg_color_space = jpeg_color_space;
      config.jparams.progressive_mode = 0;
      config.jparams.optimize_coding = 0;
      config.jparams.use_flat_dc_luma_code = flat_dc_luma;
      all_tests.push_back(config);
    }
  }
  // Test for jpeg without DHT marker.
  {
    TestConfig config;
    config.jparams.progressive_mode = 0;
    config.jparams.optimize_coding = 0;
    config.jparams.omit_standard_tables = true;
    all_tests.push_back(config);
  }
  // Test for custom component ids.
  {
    TestConfig config;
    config.input.xsize = config.input.ysize = 128;
    config.jparams.comp_ids = {7, 17, 177};
    all_tests.push_back(config);
  }
  // Tests for JFIF/Adobe markers.
  for (int override_JFIF : {-1, 0, 1}) {
    for (int override_Adobe : {-1, 0, 1}) {
      if (override_JFIF == -1 && override_Adobe == -1) continue;
      TestConfig config;
      config.input.xsize = config.input.ysize = 128;
      config.jparams.override_JFIF = override_JFIF;
      config.jparams.override_Adobe = override_Adobe;
      all_tests.push_back(config);
    }
  }
  // Tests for small images.
  for (int xsize : {1, 7, 8, 9, 15, 16, 17}) {
    for (int ysize : {1, 7, 8, 9, 15, 16, 17}) {
      TestConfig config;
      config.input.xsize = xsize;
      config.input.ysize = ysize;
      all_tests.push_back(config);
    }
  }
  // Tests for custom marker processor.
  for (size_t chunk_size : {0, 1, 64, 65536}) {
    TestConfig config;
    config.input.xsize = config.input.ysize = 256;
    config.dparams.chunk_size = chunk_size;
    config.jparams.add_marker = true;
    all_tests.push_back(config);
  }
  // Tests for icc profile decoding.
  for (size_t icc_size : {728, 70000, 1000000}) {
    TestConfig config;
    config.input.xsize = config.input.ysize = 256;
    config.jparams.icc.resize(icc_size);
    for (size_t i = 0; i < icc_size; ++i) {
      config.jparams.icc[i] = (i * 17) & 0xff;
    }
    all_tests.push_back(config);
  }
  // Tests for unusual sampling factors.
  for (int h0_samp : {1, 2, 3, 4}) {
    for (int v0_samp : {1, 2, 3, 4}) {
      for (int dxb = 0; dxb < h0_samp; ++dxb) {
        for (int dyb = 0; dyb < v0_samp; ++dyb) {
          for (int dx = 0; dx < 2; ++dx) {
            for (int dy = 0; dy < 2; ++dy) {
              TestConfig config;
              config.input.xsize = 128 + dyb * 8 + dy;
              config.input.ysize = 256 + dxb * 8 + dx;
              config.jparams.progressive_mode = 2;
              config.jparams.h_sampling = {h0_samp, 1, 1};
              config.jparams.v_sampling = {v0_samp, 1, 1};
              config.compare_to_orig = true;
              all_tests.push_back(config);
            }
          }
        }
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
          config.compare_to_orig = true;
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
          all_tests.push_back(config);
        }
      }
    }
  }
  // Tests for output scaling.
  for (int scale_num = 1; scale_num <= 16; ++scale_num) {
    if (scale_num == 8) continue;
    for (bool crop : {false, true}) {
      for (int samp : {1, 2}) {
        for (int progr : {0, 2}) {
          TestConfig config;
          config.jparams.h_sampling = {samp, 1, 1};
          config.jparams.v_sampling = {samp, 1, 1};
          config.jparams.progressive_mode = progr;
          config.dparams.scale_num = scale_num;
          config.dparams.scale_denom = 8;
          config.dparams.crop_output = crop;
          all_tests.push_back(config);
        }
      }
    }
  }
  return all_tests;
}

std::string QuantMode(ColorQuantMode mode) {
  switch (mode) {
    case CQUANT_1PASS:
      return "1pass";
    case CQUANT_EXTERNAL:
      return "External";
    case CQUANT_2PASS:
      return "2pass";
    case CQUANT_REUSE:
      return "Reuse";
  }
  return "";
}

std::string DitherMode(J_DITHER_MODE mode) {
  switch (mode) {
    case JDITHER_NONE:
      return "No";
    case JDITHER_ORDERED:
      return "Ordered";
    case JDITHER_FS:
      return "FS";
  }
  return "";
}

std::ostream& operator<<(std::ostream& os, const DecompressParams& dparams) {
  if (dparams.chunk_size == 0) {
    os << "CompleteInput";
  } else {
    os << "InputChunks" << dparams.chunk_size;
  }
  if (dparams.size_factor < 1.0f) {
    os << "Partial" << static_cast<int>(dparams.size_factor * 100) << "p";
  }
  if (dparams.max_output_lines == 0) {
    os << "CompleteOutput";
  } else {
    os << "OutputLines" << dparams.max_output_lines;
  }
  if (dparams.output_mode == RAW_DATA) {
    os << "RawDataOut";
  } else if (dparams.output_mode == COEFFICIENTS) {
    os << "CoeffsOut";
  }
  os << IOMethodName(dparams.data_type, dparams.endianness);
  if (dparams.set_out_color_space) {
    os << "OutColor" << ColorSpaceName((J_COLOR_SPACE)dparams.out_color_space);
  }
  if (dparams.crop_output) {
    os << "Crop";
  }
  if (dparams.do_block_smoothing) {
    os << "BlockSmoothing";
  }
  if (!dparams.do_fancy_upsampling) {
    os << "NoFancyUpsampling";
  }
  if (dparams.scale_num != 1 || dparams.scale_denom != 1) {
    os << "Scale" << dparams.scale_num << "_" << dparams.scale_denom;
  }
  if (dparams.quantize_colors) {
    os << "Quant" << dparams.desired_number_of_colors << "colors";
    for (size_t i = 0; i < dparams.scan_params.size(); ++i) {
      if (i > 0) os << "_";
      const auto& sparam = dparams.scan_params[i];
      os << QuantMode(sparam.color_quant_mode);
      os << DitherMode((J_DITHER_MODE)sparam.dither_mode) << "Dither";
    }
  }
  if (dparams.skip_scans) {
    os << "SkipScans";
  }
  return os;
}

std::ostream& operator<<(std::ostream& os, const TestConfig& c) {
  if (!c.fn.empty()) {
    os << c.fn_desc;
  } else {
    os << c.input;
  }
  os << c.jparams;
  os << c.dparams;
  return os;
}

std::string TestDescription(const testing::TestParamInfo<TestConfig>& info) {
  std::stringstream name;
  name << info.param;
  return name.str();
}

JPEGLI_INSTANTIATE_TEST_SUITE_P(DecodeAPITest, DecodeAPITestParam,
                                testing::ValuesIn(GenerateTests(false)),
                                TestDescription);

JPEGLI_INSTANTIATE_TEST_SUITE_P(DecodeAPITestBuffered,
                                DecodeAPITestParamBuffered,
                                testing::ValuesIn(GenerateTests(true)),
                                TestDescription);

}  // namespace
}  // namespace jpegli
