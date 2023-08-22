// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_DEC_PNM_H_
#define LIB_EXTRAS_DEC_PNM_H_

// Decodes PBM/PGM/PPM/PFM pixels in memory.

#include <stddef.h>
#include <stdint.h>

// TODO(janwas): workaround for incorrect Win64 codegen (cause unknown)
#include <hwy/highway.h>

#include "lib/extras/dec/color_hints.h"
#include "lib/extras/packed_image.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/base/status.h"

namespace jxl {

struct SizeConstraints;

namespace extras {

// Decodes `bytes` into `ppf`. color_hints may specify "color_space", which
// defaults to sRGB.
Status DecodeImagePNM(Span<const uint8_t> bytes, const ColorHints& color_hints,
                      PackedPixelFile* ppf,
                      const SizeConstraints* constraints = nullptr);

void TestCodecPNM();

}  // namespace extras
}  // namespace jxl

#endif  // LIB_EXTRAS_DEC_PNM_H_
