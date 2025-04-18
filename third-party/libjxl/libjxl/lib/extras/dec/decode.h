// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_DEC_DECODE_H_
#define LIB_EXTRAS_DEC_DECODE_H_

// Facade for image decoders (PNG, PNM, ...).

#include <stddef.h>
#include <stdint.h>

#include <string>
#include <vector>

#include "lib/extras/dec/color_hints.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/base/status.h"

namespace jxl {

struct SizeConstraints;

namespace extras {

// Codecs supported by DecodeBytes.
enum class Codec : uint32_t {
  kUnknown,  // for CodecFromPath
  kPNG,
  kPNM,
  kPGX,
  kJPG,
  kGIF,
  kEXR,
  kJXL
};

bool CanDecode(Codec codec);

// If and only if extension is ".pfm", *bits_per_sample is updated to 32 so
// that Encode() would encode to PFM instead of PPM.
Codec CodecFromPath(std::string path,
                    size_t* JXL_RESTRICT bits_per_sample = nullptr,
                    std::string* basename = nullptr,
                    std::string* extension = nullptr);

// Decodes "bytes" info *ppf.
// color_space_hint may specify the color space, otherwise, defaults to sRGB.
Status DecodeBytes(Span<const uint8_t> bytes, const ColorHints& color_hints,
                   extras::PackedPixelFile* ppf,
                   const SizeConstraints* constraints = nullptr,
                   Codec* orig_codec = nullptr);

}  // namespace extras
}  // namespace jxl

#endif  // LIB_EXTRAS_DEC_DECODE_H_
