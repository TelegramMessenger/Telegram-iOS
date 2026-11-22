// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_DEC_JPEGLI_H_
#define LIB_EXTRAS_DEC_JPEGLI_H_

// Decodes JPG pixels and metadata in memory using the libjpegli library.

#include <jxl/types.h>
#include <stdint.h>

#include <vector>

#include "lib/extras/packed_image.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"

namespace jxl {
namespace extras {

struct JpegDecompressParams {
  JxlDataType output_data_type = JXL_TYPE_UINT8;
  JxlEndianness output_endianness = JXL_NATIVE_ENDIAN;
  bool force_rgb = false;
  bool force_grayscale = false;
  int num_colors = 0;
  bool two_pass_quant = true;
  // 0 = none, 1 = ordered, 2 = Floyd-Steinberg
  int dither_mode = 2;
};

Status DecodeJpeg(const std::vector<uint8_t>& compressed,
                  const JpegDecompressParams& dparams, ThreadPool* pool,
                  PackedPixelFile* ppf);

}  // namespace extras
}  // namespace jxl

#endif  // LIB_EXTRAS_DEC_JPEGLI_H_
