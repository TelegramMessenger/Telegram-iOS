// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/dec/pgx.h"

#include <string.h>

#include "lib/extras/size_constraints.h"
#include "lib/jxl/base/bits.h"
#include "lib/jxl/base/compiler_specific.h"

namespace jxl {
namespace extras {
namespace {

struct HeaderPGX {
  // NOTE: PGX is always grayscale
  size_t xsize;
  size_t ysize;
  size_t bits_per_sample;
  bool big_endian;
  bool is_signed;
};

class Parser {
 public:
  explicit Parser(const Span<const uint8_t> bytes)
      : pos_(bytes.data()), end_(pos_ + bytes.size()) {}

  // Sets "pos" to the first non-header byte/pixel on success.
  Status ParseHeader(HeaderPGX* header, const uint8_t** pos) {
    // codec.cc ensures we have at least two bytes => no range check here.
    if (pos_[0] != 'P' || pos_[1] != 'G') return false;
    pos_ += 2;
    return ParseHeaderPGX(header, pos);
  }

  // Exposed for testing
  Status ParseUnsigned(size_t* number) {
    if (pos_ == end_) return JXL_FAILURE("PGX: reached end before number");
    if (!IsDigit(*pos_)) return JXL_FAILURE("PGX: expected unsigned number");

    *number = 0;
    while (pos_ < end_ && *pos_ >= '0' && *pos_ <= '9') {
      *number *= 10;
      *number += *pos_ - '0';
      ++pos_;
    }

    return true;
  }

 private:
  static bool IsDigit(const uint8_t c) { return '0' <= c && c <= '9'; }
  static bool IsLineBreak(const uint8_t c) { return c == '\r' || c == '\n'; }
  static bool IsWhitespace(const uint8_t c) {
    return IsLineBreak(c) || c == '\t' || c == ' ';
  }

  Status SkipSpace() {
    if (pos_ == end_) return JXL_FAILURE("PGX: reached end before space");
    const uint8_t c = *pos_;
    if (c != ' ') return JXL_FAILURE("PGX: expected space");
    ++pos_;
    return true;
  }

  Status SkipLineBreak() {
    if (pos_ == end_) return JXL_FAILURE("PGX: reached end before line break");
    // Line break can be either "\n" (0a) or "\r\n" (0d 0a).
    if (*pos_ == '\n') {
      pos_++;
      return true;
    } else if (*pos_ == '\r' && pos_ + 1 != end_ && *(pos_ + 1) == '\n') {
      pos_ += 2;
      return true;
    }
    return JXL_FAILURE("PGX: expected line break");
  }

  Status SkipSingleWhitespace() {
    if (pos_ == end_) return JXL_FAILURE("PGX: reached end before whitespace");
    if (!IsWhitespace(*pos_)) return JXL_FAILURE("PGX: expected whitespace");
    ++pos_;
    return true;
  }

  Status ParseHeaderPGX(HeaderPGX* header, const uint8_t** pos) {
    JXL_RETURN_IF_ERROR(SkipSpace());
    if (pos_ + 2 > end_) return JXL_FAILURE("PGX: header too small");
    if (*pos_ == 'M' && *(pos_ + 1) == 'L') {
      header->big_endian = true;
    } else if (*pos_ == 'L' && *(pos_ + 1) == 'M') {
      header->big_endian = false;
    } else {
      return JXL_FAILURE("PGX: invalid endianness");
    }
    pos_ += 2;
    JXL_RETURN_IF_ERROR(SkipSpace());
    if (pos_ == end_) return JXL_FAILURE("PGX: header too small");
    if (*pos_ == '+') {
      header->is_signed = false;
    } else if (*pos_ == '-') {
      header->is_signed = true;
    } else {
      return JXL_FAILURE("PGX: invalid signedness");
    }
    pos_++;
    // Skip optional space
    if (pos_ < end_ && *pos_ == ' ') pos_++;
    JXL_RETURN_IF_ERROR(ParseUnsigned(&header->bits_per_sample));
    JXL_RETURN_IF_ERROR(SkipSingleWhitespace());
    JXL_RETURN_IF_ERROR(ParseUnsigned(&header->xsize));
    JXL_RETURN_IF_ERROR(SkipSingleWhitespace());
    JXL_RETURN_IF_ERROR(ParseUnsigned(&header->ysize));
    // 0xa, or 0xd 0xa.
    JXL_RETURN_IF_ERROR(SkipLineBreak());

    // TODO(jon): could do up to 24-bit by converting the values to
    // JXL_TYPE_FLOAT.
    if (header->bits_per_sample > 16) {
      return JXL_FAILURE("PGX: >16 bits not yet supported");
    }
    // TODO(lode): support signed integers. This may require changing the way
    // external_image works.
    if (header->is_signed) {
      return JXL_FAILURE("PGX: signed not yet supported");
    }

    size_t numpixels = header->xsize * header->ysize;
    size_t bytes_per_pixel = header->bits_per_sample <= 8 ? 1 : 2;
    if (pos_ + numpixels * bytes_per_pixel > end_) {
      return JXL_FAILURE("PGX: data too small");
    }

    *pos = pos_;
    return true;
  }

  const uint8_t* pos_;
  const uint8_t* const end_;
};

}  // namespace

Status DecodeImagePGX(const Span<const uint8_t> bytes,
                      const ColorHints& color_hints, PackedPixelFile* ppf,
                      const SizeConstraints* constraints) {
  Parser parser(bytes);
  HeaderPGX header = {};
  const uint8_t* pos;
  if (!parser.ParseHeader(&header, &pos)) return false;
  JXL_RETURN_IF_ERROR(
      VerifyDimensions(constraints, header.xsize, header.ysize));
  if (header.bits_per_sample == 0 || header.bits_per_sample > 32) {
    return JXL_FAILURE("PGX: bits_per_sample invalid");
  }

  JXL_RETURN_IF_ERROR(ApplyColorHints(color_hints, /*color_already_set=*/false,
                                      /*is_gray=*/true, ppf));
  ppf->info.xsize = header.xsize;
  ppf->info.ysize = header.ysize;
  // Original data is uint, so exponent_bits_per_sample = 0.
  ppf->info.bits_per_sample = header.bits_per_sample;
  ppf->info.exponent_bits_per_sample = 0;
  ppf->info.uses_original_profile = true;

  // No alpha in PGX
  ppf->info.alpha_bits = 0;
  ppf->info.alpha_exponent_bits = 0;
  ppf->info.num_color_channels = 1;  // Always grayscale
  ppf->info.orientation = JXL_ORIENT_IDENTITY;

  JxlDataType data_type;
  if (header.bits_per_sample > 8) {
    data_type = JXL_TYPE_UINT16;
  } else {
    data_type = JXL_TYPE_UINT8;
  }

  const JxlPixelFormat format{
      /*num_channels=*/1,
      /*data_type=*/data_type,
      /*endianness=*/header.big_endian ? JXL_BIG_ENDIAN : JXL_LITTLE_ENDIAN,
      /*align=*/0,
  };
  ppf->frames.clear();
  // Allocates the frame buffer.
  ppf->frames.emplace_back(header.xsize, header.ysize, format);
  const auto& frame = ppf->frames.back();
  size_t pgx_remaining_size = bytes.data() + bytes.size() - pos;
  if (pgx_remaining_size < frame.color.pixels_size) {
    return JXL_FAILURE("PGX file too small");
  }
  memcpy(frame.color.pixels(), pos, frame.color.pixels_size);
  return true;
}

}  // namespace extras
}  // namespace jxl
