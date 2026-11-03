// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_TEST_PARAMS_H_
#define LIB_JPEGLI_TEST_PARAMS_H_

#include <stddef.h>
#include <stdint.h>

#include <algorithm>
#include <vector>

#include "lib/jpegli/types.h"

namespace jpegli {

// We define this here as well to make sure that the *_api_test.cc tests only
// use the public API and therefore we don't include any *_internal.h headers.
template <typename T1, typename T2>
constexpr inline T1 DivCeil(T1 a, T2 b) {
  return (a + b - 1) / b;
}

#define ARRAY_SIZE(X) (sizeof(X) / sizeof((X)[0]))

static constexpr int kLastScan = 0xffff;

static uint32_t kTestColorMap[] = {
    0x000000, 0xff0000, 0x00ff00, 0x0000ff, 0xffff00, 0x00ffff,
    0xff00ff, 0xffffff, 0x6251fc, 0x45d9c7, 0xa7f059, 0xd9a945,
    0xfa4e44, 0xceaffc, 0xbad7db, 0xc1f0b1, 0xdbca9a, 0xfacac5,
    0xf201ff, 0x0063db, 0x00f01c, 0xdbb204, 0xf12f0c, 0x7ba1dc};
static constexpr int kTestColorMapNumColors = ARRAY_SIZE(kTestColorMap);

static constexpr int kSpecialMarker0 = 0xe5;
static constexpr int kSpecialMarker1 = 0xe9;
static constexpr uint8_t kMarkerData[] = {0, 1, 255, 0, 17};
static constexpr uint8_t kMarkerSequence[] = {0xe6, 0xe8, 0xe7,
                                              0xe6, 0xe7, 0xe8};
static constexpr size_t kMarkerSequenceLen = ARRAY_SIZE(kMarkerSequence);

enum JpegIOMode {
  PIXELS,
  RAW_DATA,
  COEFFICIENTS,
};

struct CustomQuantTable {
  int slot_idx = 0;
  uint16_t table_type = 0;
  int scale_factor = 100;
  bool add_raw = false;
  bool force_baseline = true;
  std::vector<unsigned int> basic_table;
  std::vector<unsigned int> quantval;
  void Generate();
};

struct TestImage {
  size_t xsize = 2268;
  size_t ysize = 1512;
  int color_space = 2;  // JCS_RGB
  size_t components = 3;
  JpegliDataType data_type = JPEGLI_TYPE_UINT8;
  JpegliEndianness endianness = JPEGLI_NATIVE_ENDIAN;
  std::vector<uint8_t> pixels;
  std::vector<std::vector<uint8_t>> raw_data;
  std::vector<std::vector<int16_t>> coeffs;
  void AllocatePixels() {
    pixels.resize(ysize * xsize * components *
                  jpegli_bytes_per_sample(data_type));
  }
  void Clear() {
    pixels.clear();
    raw_data.clear();
    coeffs.clear();
  }
};

struct CompressParams {
  int quality = 90;
  bool set_jpeg_colorspace = false;
  int jpeg_color_space = 0;  // JCS_UNKNOWN
  std::vector<int> quant_indexes;
  std::vector<CustomQuantTable> quant_tables;
  std::vector<int> h_sampling;
  std::vector<int> v_sampling;
  std::vector<int> comp_ids;
  int override_JFIF = -1;
  int override_Adobe = -1;
  bool add_marker = false;
  bool simple_progression = false;
  // -1 is library default
  // 0, 1, 2 is set through jpegli_set_progressive_level()
  // 2 + N is kScriptN
  int progressive_mode = -1;
  unsigned int restart_interval = 0;
  int restart_in_rows = 0;
  int smoothing_factor = 0;
  int optimize_coding = -1;
  bool use_flat_dc_luma_code = false;
  bool omit_standard_tables = false;
  bool xyb_mode = false;
  bool libjpeg_mode = false;
  bool use_adaptive_quantization = true;
  std::vector<uint8_t> icc;

  int h_samp(int c) const { return h_sampling.empty() ? 1 : h_sampling[c]; }
  int v_samp(int c) const { return v_sampling.empty() ? 1 : v_sampling[c]; }
  int max_h_sample() const {
    auto it = std::max_element(h_sampling.begin(), h_sampling.end());
    return it == h_sampling.end() ? 1 : *it;
  }
  int max_v_sample() const {
    auto it = std::max_element(v_sampling.begin(), v_sampling.end());
    return it == v_sampling.end() ? 1 : *it;
  }
  int comp_width(const TestImage& input, int c) const {
    return DivCeil(input.xsize * h_samp(c), max_h_sample() * 8) * 8;
  }
  int comp_height(const TestImage& input, int c) const {
    return DivCeil(input.ysize * v_samp(c), max_v_sample() * 8) * 8;
  }
};

enum ColorQuantMode {
  CQUANT_1PASS,
  CQUANT_2PASS,
  CQUANT_EXTERNAL,
  CQUANT_REUSE,
};

struct ScanDecompressParams {
  int max_scan_number;
  int dither_mode;
  ColorQuantMode color_quant_mode;
};

struct DecompressParams {
  float size_factor = 1.0f;
  size_t chunk_size = 65536;
  size_t max_output_lines = 16;
  JpegIOMode output_mode = PIXELS;
  JpegliDataType data_type = JPEGLI_TYPE_UINT8;
  JpegliEndianness endianness = JPEGLI_NATIVE_ENDIAN;
  bool set_out_color_space = false;
  int out_color_space = 0;  // JCS_UNKNOWN
  bool crop_output = false;
  bool do_block_smoothing = false;
  bool do_fancy_upsampling = true;
  bool skip_scans = false;
  int scale_num = 1;
  int scale_denom = 1;
  bool quantize_colors = false;
  int desired_number_of_colors = 256;
  std::vector<ScanDecompressParams> scan_params;
};

}  // namespace jpegli

#endif  // LIB_JPEGLI_TEST_PARAMS_H_
