// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_TEST_UTILS_H_
#define LIB_JPEGLI_TEST_UTILS_H_

#include <stddef.h>
#include <stdint.h>

#include <algorithm>
#include <string>
#include <vector>

/* clang-format off */
#include <stdio.h>
#include <jpeglib.h>
#include <setjmp.h>
/* clang-format on */

#include "lib/jpegli/common.h"
#include "lib/jpegli/libjpeg_test_util.h"
#include "lib/jpegli/test_params.h"

namespace jpegli {

#define ERROR_HANDLER_SETUP(flavor)                                \
  jpeg_error_mgr jerr;                                             \
  jmp_buf env;                                                     \
  cinfo.err = flavor##_std_error(&jerr);                           \
  if (setjmp(env)) {                                               \
    return false;                                                  \
  }                                                                \
  cinfo.client_data = reinterpret_cast<void*>(&env);               \
  cinfo.err->error_exit = [](j_common_ptr cinfo) {                 \
    (*cinfo->err->output_message)(cinfo);                          \
    jmp_buf* env = reinterpret_cast<jmp_buf*>(cinfo->client_data); \
    flavor##_destroy(cinfo);                                       \
    longjmp(*env, 1);                                              \
  };

std::string IOMethodName(JpegliDataType data_type, JpegliEndianness endianness);

std::string ColorSpaceName(J_COLOR_SPACE colorspace);

std::ostream& operator<<(std::ostream& os, const TestImage& input);

std::ostream& operator<<(std::ostream& os, const CompressParams& jparams);

int NumTestScanScripts();

void VerifyHeader(const CompressParams& jparams, j_decompress_ptr cinfo);
void VerifyScanHeader(const CompressParams& jparams, j_decompress_ptr cinfo);

void SetDecompressParams(const DecompressParams& dparams,
                         j_decompress_ptr cinfo);

void SetScanDecompressParams(const DecompressParams& dparams,
                             j_decompress_ptr cinfo, int scan_number);

void CopyCoefficients(j_decompress_ptr cinfo, jvirt_barray_ptr* coef_arrays,
                      TestImage* output);

void UnmapColors(uint8_t* row, size_t xsize, int components,
                 JSAMPARRAY colormap, size_t num_colors);

std::string GetTestDataPath(const std::string& filename);
std::vector<uint8_t> ReadTestData(const std::string& filename);

class PNMParser {
 public:
  explicit PNMParser(const uint8_t* data, const size_t len)
      : pos_(data), end_(data + len) {}

  // Sets "pos" to the first non-header byte/pixel on success.
  bool ParseHeader(const uint8_t** pos, size_t* xsize, size_t* ysize,
                   size_t* num_channels, size_t* bitdepth);

 private:
  static bool IsLineBreak(const uint8_t c) { return c == '\r' || c == '\n'; }
  static bool IsWhitespace(const uint8_t c) {
    return IsLineBreak(c) || c == '\t' || c == ' ';
  }

  bool ParseUnsigned(size_t* number);

  bool SkipWhitespace();

  const uint8_t* pos_;
  const uint8_t* const end_;
};

bool ReadPNM(const std::vector<uint8_t>& data, size_t* xsize, size_t* ysize,
             size_t* num_channels, size_t* bitdepth,
             std::vector<uint8_t>* pixels);

void SetNumChannels(J_COLOR_SPACE colorspace, size_t* channels);

void ConvertToGrayscale(TestImage* img);

void GeneratePixels(TestImage* img);

void GenerateRawData(const CompressParams& jparams, TestImage* img);

void GenerateCoeffs(const CompressParams& jparams, TestImage* img);

void EncodeWithJpegli(const TestImage& input, const CompressParams& jparams,
                      j_compress_ptr cinfo);

bool EncodeWithJpegli(const TestImage& input, const CompressParams& jparams,
                      std::vector<uint8_t>* compressed);

double DistanceRms(const TestImage& input, const TestImage& output,
                   size_t start_line, size_t num_lines,
                   double* max_diff = nullptr);

double DistanceRms(const TestImage& input, const TestImage& output,
                   double* max_diff = nullptr);

void VerifyOutputImage(const TestImage& input, const TestImage& output,
                       size_t start_line, size_t num_lines, double max_rms,
                       double max_diff = 255.0);

void VerifyOutputImage(const TestImage& input, const TestImage& output,
                       double max_rms, double max_diff = 255.0);

}  // namespace jpegli

#endif  // LIB_JPEGLI_TEST_UTILS_H_
