// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/codec.h"

#include <jxl/decode.h>
#include <jxl/types.h>

#include "lib/extras/dec/decode.h"
#include "lib/extras/enc/apng.h"
#include "lib/extras/enc/exr.h"
#include "lib/extras/enc/jpg.h"
#include "lib/extras/enc/pgx.h"
#include "lib/extras/enc/pnm.h"
#include "lib/extras/packed_image.h"
#include "lib/extras/packed_image_convert.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/image_bundle.h"

namespace jxl {
namespace {

// Any valid encoding is larger (ensures codecs can read the first few bytes)
constexpr size_t kMinBytes = 9;

}  // namespace

Status SetFromBytes(const Span<const uint8_t> bytes,
                    const extras::ColorHints& color_hints, CodecInOut* io,
                    ThreadPool* pool, const SizeConstraints* constraints,
                    extras::Codec* orig_codec) {
  if (bytes.size() < kMinBytes) return JXL_FAILURE("Too few bytes");

  extras::PackedPixelFile ppf;
  if (extras::DecodeBytes(bytes, color_hints, &ppf, constraints, orig_codec)) {
    return ConvertPackedPixelFileToCodecInOut(ppf, pool, io);
  }
  return JXL_FAILURE("Codecs failed to decode");
}

Status Encode(const CodecInOut& io, const extras::Codec codec,
              const ColorEncoding& c_desired, size_t bits_per_sample,
              std::vector<uint8_t>* bytes, ThreadPool* pool) {
  bytes->clear();
  JXL_CHECK(!io.Main().c_current().ICC().empty());
  JXL_CHECK(!c_desired.ICC().empty());
  io.CheckMetadata();
  if (io.Main().IsJPEG()) {
    JXL_WARNING("Writing JPEG data as pixels");
  }
  JxlPixelFormat format = {
      0,  // num_channels is ignored by the converter
      bits_per_sample <= 8 ? JXL_TYPE_UINT8 : JXL_TYPE_UINT16, JXL_BIG_ENDIAN,
      0};
  const bool floating_point = bits_per_sample > 16;
  std::unique_ptr<extras::Encoder> encoder;
  std::ostringstream os;
  switch (codec) {
    case extras::Codec::kPNG:
      encoder = extras::GetAPNGEncoder();
      if (encoder) {
        break;
      } else {
        return JXL_FAILURE("JPEG XL was built without (A)PNG support");
      }
    case extras::Codec::kJPG:
      format.data_type = JXL_TYPE_UINT8;
      encoder = extras::GetJPEGEncoder();
      if (encoder) {
        os << io.jpeg_quality;
        encoder->SetOption("q", os.str());
        break;
      } else {
        return JXL_FAILURE("JPEG XL was built without JPEG support");
      }
    case extras::Codec::kPNM:
      if (io.Main().HasAlpha()) {
        encoder = extras::GetPAMEncoder();
      } else if (io.Main().IsGray()) {
        encoder = extras::GetPGMEncoder();
      } else if (!floating_point) {
        encoder = extras::GetPPMEncoder();
      } else {
        format.data_type = JXL_TYPE_FLOAT;
        format.endianness = JXL_LITTLE_ENDIAN;
        encoder = extras::GetPFMEncoder();
      }
      break;
    case extras::Codec::kPGX:
      encoder = extras::GetPGXEncoder();
      break;
    case extras::Codec::kGIF:
      return JXL_FAILURE("Encoding to GIF is not implemented");
    case extras::Codec::kEXR:
      format.data_type = JXL_TYPE_FLOAT;
      encoder = extras::GetEXREncoder();
      if (encoder) {
        break;
      } else {
        return JXL_FAILURE("JPEG XL was built without OpenEXR support");
      }
    case extras::Codec::kJXL:
      return JXL_FAILURE("TODO: encode using Codec::kJXL");

    case extras::Codec::kUnknown:
      return JXL_FAILURE("Cannot encode using Codec::kUnknown");
  }

  if (!encoder) {
    return JXL_FAILURE("Invalid codec.");
  }

  extras::PackedPixelFile ppf;
  JXL_RETURN_IF_ERROR(
      ConvertCodecInOutToPackedPixelFile(io, format, c_desired, pool, &ppf));
  ppf.info.bits_per_sample = bits_per_sample;
  if (format.data_type == JXL_TYPE_FLOAT) {
    ppf.info.bits_per_sample = 32;
    ppf.info.exponent_bits_per_sample = 8;
  }
  extras::EncodedImage encoded_image;
  JXL_RETURN_IF_ERROR(encoder->Encode(ppf, &encoded_image, pool));
  JXL_ASSERT(encoded_image.bitstreams.size() == 1);
  *bytes = encoded_image.bitstreams[0];

  return true;
}

Status Encode(const CodecInOut& io, const ColorEncoding& c_desired,
              size_t bits_per_sample, const std::string& pathname,
              std::vector<uint8_t>* bytes, ThreadPool* pool) {
  std::string extension;
  const extras::Codec codec = extras::CodecFromPath(
      pathname, &bits_per_sample, /* basename */ nullptr, &extension);

  // Warn about incorrect usage of PGM/PGX/PPM - only the latter supports
  // color, but CodecFromPath lumps them all together.
  if (codec == extras::Codec::kPNM && extension != ".pfm") {
    if (io.Main().HasAlpha() && extension != ".pam") {
      JXL_WARNING(
          "For images with alpha, the filename should end with .pam.\n");
    } else if (!io.Main().IsGray() && extension == ".pgm") {
      JXL_WARNING("For color images, the filename should end with .ppm.\n");
    } else if (io.Main().IsGray() && extension == ".ppm") {
      JXL_WARNING(
          "For grayscale images, the filename should not end with .ppm.\n");
    }
    if (bits_per_sample > 16) {
      JXL_WARNING("PPM only supports up to 16 bits per sample");
      bits_per_sample = 16;
    }
  } else if (codec == extras::Codec::kPGX && !io.Main().IsGray()) {
    JXL_WARNING("Storing color image to PGX - use .ppm extension instead.\n");
  }
  if (bits_per_sample > 16 && codec == extras::Codec::kPNG) {
    JXL_WARNING("PNG only supports up to 16 bits per sample");
    bits_per_sample = 16;
  }

  return Encode(io, codec, c_desired, bits_per_sample, bytes, pool);
}

Status Encode(const CodecInOut& io, const std::string& pathname,
              std::vector<uint8_t>* bytes, ThreadPool* pool) {
  // TODO(lode): need to take the floating_point_sample field into account
  return Encode(io, io.metadata.m.color_encoding,
                io.metadata.m.bit_depth.bits_per_sample, pathname, bytes, pool);
}

}  // namespace jxl
