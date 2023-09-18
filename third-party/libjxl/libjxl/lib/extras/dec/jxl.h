// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_DEC_JXL_H_
#define LIB_EXTRAS_DEC_JXL_H_

// Decodes JPEG XL images in memory.

#include <jxl/parallel_runner.h>
#include <jxl/types.h>
#include <stdint.h>

#include <limits>
#include <string>
#include <vector>

#include "lib/extras/packed_image.h"

namespace jxl {
namespace extras {

struct JXLDecompressParams {
  // If empty, little endian float formats will be accepted.
  std::vector<JxlPixelFormat> accepted_formats;

  // Requested output color space description.
  std::string color_space;
  // If set, performs tone mapping to this intensity target luminance.
  float display_nits = 0.0;
  // Whether spot colors are rendered on the image.
  bool render_spotcolors = true;
  // Whether to keep or undo the orientation given in the header.
  bool keep_orientation = false;

  // If runner_opaque is set, the decoder uses this parallel runner.
  JxlParallelRunner runner;
  void* runner_opaque = nullptr;

  // Whether truncated input should be treated as an error.
  bool allow_partial_input = false;

  // Set to true if an ICC profile has to be synthesized for Enum color
  // encodings
  bool need_icc = false;

  // How many passes to decode at most. By default, decode everything.
  uint32_t max_passes = std::numeric_limits<uint32_t>::max();

  // Alternatively, one can specify the maximum tolerable downscaling factor
  // with respect to the full size of the image. By default, nothing less than
  // the full size is requested.
  size_t max_downsampling = 1;

  // Whether to use the image callback or the image buffer to get the output.
  bool use_image_callback = true;
  // Whether to unpremultiply colors for associated alpha channels.
  bool unpremultiply_alpha = false;

  // Controls the effective bit depth of the output pixels.
  JxlBitDepth output_bitdepth = {JXL_BIT_DEPTH_FROM_CODESTREAM, 0, 0};
};

bool DecodeImageJXL(const uint8_t* bytes, size_t bytes_size,
                    const JXLDecompressParams& dparams, size_t* decoded_bytes,
                    PackedPixelFile* ppf,
                    std::vector<uint8_t>* jpeg_bytes = nullptr);

}  // namespace extras
}  // namespace jxl

#endif  // LIB_EXTRAS_DEC_JXL_H_
