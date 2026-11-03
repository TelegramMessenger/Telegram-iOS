// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_DEBUG_IMAGE_H_
#define LIB_JXL_ENC_DEBUG_IMAGE_H_

// Optional output images for debugging.

#include <stddef.h>
#include <stdint.h>

#include "lib/jxl/enc_params.h"
#include "lib/jxl/image.h"

namespace jxl {

void DumpImage(const CompressParams& cparams, const char* label,
               const Image3<float>& image);
void DumpImage(const CompressParams& cparams, const char* label,
               const Image3<uint8_t>& image);
void DumpXybImage(const CompressParams& cparams, const char* label,
                  const Image3<float>& image);
void DumpPlaneNormalized(const CompressParams& cparams, const char* label,
                         const Plane<float>& image);
void DumpPlaneNormalized(const CompressParams& cparams, const char* label,
                         const Plane<uint8_t>& image);

// Used to skip image creation if they won't be written to debug directory.
static inline bool WantDebugOutput(const CompressParams& cparams) {
  return cparams.debug_image != nullptr;
}

}  // namespace jxl

#endif  // LIB_JXL_ENC_DEBUG_IMAGE_H_
