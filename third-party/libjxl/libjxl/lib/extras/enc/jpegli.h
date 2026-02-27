// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_ENC_JPEGLI_H_
#define LIB_EXTRAS_ENC_JPEGLI_H_

// Encodes JPG pixels and metadata in memory using the libjpegli library.

#include <stdint.h>

#include <string>
#include <vector>

#include "lib/extras/packed_image.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"

namespace jxl {
namespace extras {

struct JpegSettings {
  bool xyb = false;
  size_t target_size = 0;
  float quality = 0.0f;
  float distance = 1.f;
  bool use_adaptive_quantization = true;
  bool use_std_quant_tables = false;
  int progressive_level = 2;
  bool optimize_coding = true;
  std::string chroma_subsampling;
  int libjpeg_quality = 0;
  std::string libjpeg_chroma_subsampling;
  // Parameters for selecting distance based on PSNR target.
  float psnr_target = 0.0f;
  float search_tolerance = 0.01;
  float min_distance = 0.1f;
  float max_distance = 25.0f;
  // If not empty, must contain concatenated APP marker segments. In this case,
  // these and only these APP marker segments will be written to the JPEG
  // output. In xyb mode app_data must not contain an ICC profile, in this
  // case an additional APP2 ICC profile for the XYB colorspace will be emitted.
  std::vector<uint8_t> app_data;
};

Status EncodeJpeg(const PackedPixelFile& ppf, const JpegSettings& jpeg_settings,
                  ThreadPool* pool, std::vector<uint8_t>* compressed);

}  // namespace extras
}  // namespace jxl

#endif  // LIB_EXTRAS_ENC_JPEGLI_H_
