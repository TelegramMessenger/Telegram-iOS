// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_PACKED_IMAGE_CONVERT_H_
#define LIB_EXTRAS_PACKED_IMAGE_CONVERT_H_

// Helper functions to convert from the external image types to the internal
// CodecInOut to help transitioning to the external types.

#include <jxl/types.h>

#include "lib/extras/packed_image.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/codec_in_out.h"

namespace jxl {
namespace extras {

// Converts an external PackedPixelFile to the internal CodecInOut for use with
// internal functions directly.
Status ConvertPackedPixelFileToCodecInOut(const PackedPixelFile& ppf,
                                          ThreadPool* pool, CodecInOut* io);

// Converts an internal CodecInOut for use with internal function to an external
// PackedPixelFile.
Status ConvertCodecInOutToPackedPixelFile(const CodecInOut& io,
                                          const JxlPixelFormat& pixel_format,
                                          const ColorEncoding& c_desired,
                                          ThreadPool* pool,
                                          PackedPixelFile* ppf);
}  // namespace extras
}  // namespace jxl

#endif  // LIB_EXTRAS_PACKED_IMAGE_CONVERT_H_
