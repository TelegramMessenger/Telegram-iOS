// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_ENC_JXL_H_
#define LIB_EXTRAS_ENC_JXL_H_

#include <jxl/encode.h>
#include <jxl/parallel_runner.h>
#include <jxl/thread_parallel_runner.h>
#include <jxl/types.h>
#include <stdint.h>

#include <vector>

#include "lib/extras/packed_image.h"

namespace jxl {
namespace extras {

struct JXLOption {
  JXLOption(JxlEncoderFrameSettingId id, int64_t val, size_t frame_index)
      : id(id), is_float(false), ival(val), frame_index(frame_index) {}
  JXLOption(JxlEncoderFrameSettingId id, float val, size_t frame_index)
      : id(id), is_float(true), fval(val), frame_index(frame_index) {}

  JxlEncoderFrameSettingId id;
  bool is_float;
  union {
    int64_t ival;
    float fval;
  };
  size_t frame_index;
};

struct JXLCompressParams {
  std::vector<JXLOption> options;
  // Target butteraugli distance, 0.0 means lossless.
  float distance = 1.0f;
  float alpha_distance = 1.0f;
  // If set to true, forces container mode.
  bool use_container = false;
  // Whether to enable/disable byte-exact jpeg reconstruction for jpeg inputs.
  bool jpeg_store_metadata = true;
  bool jpeg_strip_exif = false;
  bool jpeg_strip_xmp = false;
  bool jpeg_strip_jumbf = false;
  // Whether to create brob boxes.
  bool compress_boxes = true;
  // Upper bound on the intensity level present in the image in nits (zero means
  // that the library chooses a default).
  float intensity_target = 0;
  int already_downsampled = 1;
  int upsampling_mode = -1;
  // Overrides for bitdepth, codestream level and alpha premultiply.
  size_t override_bitdepth = 0;
  int32_t codestream_level = -1;
  int32_t premultiply = -1;
  // Override input buffer interpretation.
  JxlBitDepth input_bitdepth = {JXL_BIT_DEPTH_FROM_PIXEL_FORMAT, 0, 0};
  // If runner_opaque is set, the decoder uses this parallel runner.
  JxlParallelRunner runner = JxlThreadParallelRunner;
  void* runner_opaque = nullptr;
  JxlDebugImageCallback debug_image = nullptr;
  void* debug_image_opaque = nullptr;
  JxlEncoderStats* stats = nullptr;
  bool allow_expert_options = false;

  void AddOption(JxlEncoderFrameSettingId id, int64_t val) {
    options.emplace_back(JXLOption(id, val, 0));
  }
  void AddFloatOption(JxlEncoderFrameSettingId id, float val) {
    options.emplace_back(JXLOption(id, val, 0));
  }
};

bool EncodeImageJXL(const JXLCompressParams& params, const PackedPixelFile& ppf,
                    const std::vector<uint8_t>* jpeg_bytes,
                    std::vector<uint8_t>* compressed);

}  // namespace extras
}  // namespace jxl

#endif  // LIB_EXTRAS_ENC_JXL_H_
