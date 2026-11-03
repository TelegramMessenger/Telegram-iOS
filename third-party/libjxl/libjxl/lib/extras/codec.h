// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_CODEC_H_
#define LIB_EXTRAS_CODEC_H_

// Facade for image encoders/decoders (PNG, PNM, ...).

#include <stddef.h>
#include <stdint.h>

#include <string>

#include "lib/extras/dec/color_hints.h"
#include "lib/extras/dec/decode.h"
#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/field_encodings.h"  // MakeBit

namespace jxl {

struct SizeConstraints;

// Decodes "bytes" and sets io->metadata.m.
// color_space_hint may specify the color space, otherwise, defaults to sRGB.
Status SetFromBytes(Span<const uint8_t> bytes,
                    const extras::ColorHints& color_hints, CodecInOut* io,
                    ThreadPool* pool = nullptr,
                    const SizeConstraints* constraints = nullptr,
                    extras::Codec* orig_codec = nullptr);
// Helper function to use no color_space_hint.
JXL_INLINE Status SetFromBytes(const Span<const uint8_t> bytes, CodecInOut* io,
                               ThreadPool* pool = nullptr,
                               const SizeConstraints* constraints = nullptr,
                               extras::Codec* orig_codec = nullptr) {
  return SetFromBytes(bytes, extras::ColorHints(), io, pool, constraints,
                      orig_codec);
}

// Replaces "bytes" with an encoding of pixels transformed from c_current
// color space to c_desired.
Status Encode(const CodecInOut& io, extras::Codec codec,
              const ColorEncoding& c_desired, size_t bits_per_sample,
              std::vector<uint8_t>* bytes, ThreadPool* pool = nullptr);

// Deduces codec, calls Encode and writes to file.
Status Encode(const CodecInOut& io, const ColorEncoding& c_desired,
              size_t bits_per_sample, const std::string& pathname,
              std::vector<uint8_t>* bytes, ThreadPool* pool = nullptr);
// Same, but defaults to metadata.original color_encoding and bits_per_sample.
Status Encode(const CodecInOut& io, const std::string& pathname,
              std::vector<uint8_t>* bytes, ThreadPool* pool = nullptr);

}  // namespace jxl

#endif  // LIB_EXTRAS_CODEC_H_
