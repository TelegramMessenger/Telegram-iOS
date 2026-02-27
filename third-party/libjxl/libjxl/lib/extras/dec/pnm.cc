// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/dec/pnm.h"

#include <stdlib.h>
#include <string.h>

#include <cmath>

#include "lib/extras/size_constraints.h"
#include "lib/jxl/base/bits.h"
#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/status.h"

namespace jxl {
namespace extras {
namespace {

struct HeaderPNM {
  size_t xsize;
  size_t ysize;
  bool is_gray;    // PGM
  bool has_alpha;  // PAM
  size_t bits_per_sample;
  bool floating_point;
  bool big_endian;
  std::vector<JxlExtraChannelType> ec_types;  // PAM
};

class Parser {
 public:
  explicit Parser(const Span<const uint8_t> bytes)
      : pos_(bytes.data()), end_(pos_ + bytes.size()) {}

  // Sets "pos" to the first non-header byte/pixel on success.
  Status ParseHeader(HeaderPNM* header, const uint8_t** pos) {
    // codec.cc ensures we have at least two bytes => no range check here.
    if (pos_[0] != 'P') return false;
    const uint8_t type = pos_[1];
    pos_ += 2;

    switch (type) {
      case '4':
        return JXL_FAILURE("pbm not supported");

      case '5':
        header->is_gray = true;
        return ParseHeaderPNM(header, pos);

      case '6':
        header->is_gray = false;
        return ParseHeaderPNM(header, pos);

      case '7':
        return ParseHeaderPAM(header, pos);

      case 'F':
        header->is_gray = false;
        return ParseHeaderPFM(header, pos);

      case 'f':
        header->is_gray = true;
        return ParseHeaderPFM(header, pos);
    }
    return false;
  }

  // Exposed for testing
  Status ParseUnsigned(size_t* number) {
    if (pos_ == end_) return JXL_FAILURE("PNM: reached end before number");
    if (!IsDigit(*pos_)) return JXL_FAILURE("PNM: expected unsigned number");

    *number = 0;
    while (pos_ < end_ && *pos_ >= '0' && *pos_ <= '9') {
      *number *= 10;
      *number += *pos_ - '0';
      ++pos_;
    }

    return true;
  }

  Status ParseSigned(double* number) {
    if (pos_ == end_) return JXL_FAILURE("PNM: reached end before signed");

    if (*pos_ != '-' && *pos_ != '+' && !IsDigit(*pos_)) {
      return JXL_FAILURE("PNM: expected signed number");
    }

    // Skip sign
    const bool is_neg = *pos_ == '-';
    if (is_neg || *pos_ == '+') {
      ++pos_;
      if (pos_ == end_) return JXL_FAILURE("PNM: reached end before digits");
    }

    // Leading digits
    *number = 0.0;
    while (pos_ < end_ && *pos_ >= '0' && *pos_ <= '9') {
      *number *= 10;
      *number += *pos_ - '0';
      ++pos_;
    }

    // Decimal places?
    if (pos_ < end_ && *pos_ == '.') {
      ++pos_;
      double place = 0.1;
      while (pos_ < end_ && *pos_ >= '0' && *pos_ <= '9') {
        *number += (*pos_ - '0') * place;
        place *= 0.1;
        ++pos_;
      }
    }

    if (is_neg) *number = -*number;
    return true;
  }

 private:
  static bool IsDigit(const uint8_t c) { return '0' <= c && c <= '9'; }
  static bool IsLineBreak(const uint8_t c) { return c == '\r' || c == '\n'; }
  static bool IsWhitespace(const uint8_t c) {
    return IsLineBreak(c) || c == '\t' || c == ' ';
  }

  Status SkipBlank() {
    if (pos_ == end_) return JXL_FAILURE("PNM: reached end before blank");
    const uint8_t c = *pos_;
    if (c != ' ' && c != '\n') return JXL_FAILURE("PNM: expected blank");
    ++pos_;
    return true;
  }

  Status SkipSingleWhitespace() {
    if (pos_ == end_) return JXL_FAILURE("PNM: reached end before whitespace");
    if (!IsWhitespace(*pos_)) return JXL_FAILURE("PNM: expected whitespace");
    ++pos_;
    return true;
  }

  Status SkipWhitespace() {
    if (pos_ == end_) return JXL_FAILURE("PNM: reached end before whitespace");
    if (!IsWhitespace(*pos_) && *pos_ != '#') {
      return JXL_FAILURE("PNM: expected whitespace/comment");
    }

    while (pos_ < end_ && IsWhitespace(*pos_)) {
      ++pos_;
    }

    // Comment(s)
    while (pos_ != end_ && *pos_ == '#') {
      while (pos_ != end_ && !IsLineBreak(*pos_)) {
        ++pos_;
      }
      // Newline(s)
      while (pos_ != end_ && IsLineBreak(*pos_)) pos_++;
    }

    while (pos_ < end_ && IsWhitespace(*pos_)) {
      ++pos_;
    }
    return true;
  }

  Status MatchString(const char* keyword, bool skipws = true) {
    const uint8_t* ppos = pos_;
    while (*keyword) {
      if (ppos >= end_) return JXL_FAILURE("PAM: unexpected end of input");
      if (*keyword != *ppos) return false;
      ppos++;
      keyword++;
    }
    pos_ = ppos;
    if (skipws) {
      JXL_RETURN_IF_ERROR(SkipWhitespace());
    } else {
      JXL_RETURN_IF_ERROR(SkipSingleWhitespace());
    }
    return true;
  }

  Status ParseHeaderPAM(HeaderPNM* header, const uint8_t** pos) {
    size_t depth = 3;
    size_t max_val = 255;
    JXL_RETURN_IF_ERROR(SkipWhitespace());
    while (!MatchString("ENDHDR", /*skipws=*/false)) {
      if (MatchString("WIDTH")) {
        JXL_RETURN_IF_ERROR(ParseUnsigned(&header->xsize));
        JXL_RETURN_IF_ERROR(SkipWhitespace());
      } else if (MatchString("HEIGHT")) {
        JXL_RETURN_IF_ERROR(ParseUnsigned(&header->ysize));
        JXL_RETURN_IF_ERROR(SkipWhitespace());
      } else if (MatchString("DEPTH")) {
        JXL_RETURN_IF_ERROR(ParseUnsigned(&depth));
        JXL_RETURN_IF_ERROR(SkipWhitespace());
      } else if (MatchString("MAXVAL")) {
        JXL_RETURN_IF_ERROR(ParseUnsigned(&max_val));
        JXL_RETURN_IF_ERROR(SkipWhitespace());
      } else if (MatchString("TUPLTYPE")) {
        if (MatchString("RGB_ALPHA")) {
          header->has_alpha = true;
        } else if (MatchString("RGB")) {
        } else if (MatchString("GRAYSCALE_ALPHA")) {
          header->has_alpha = true;
          header->is_gray = true;
        } else if (MatchString("GRAYSCALE")) {
          header->is_gray = true;
        } else if (MatchString("BLACKANDWHITE_ALPHA")) {
          header->has_alpha = true;
          header->is_gray = true;
          max_val = 1;
        } else if (MatchString("BLACKANDWHITE")) {
          header->is_gray = true;
          max_val = 1;
        } else if (MatchString("Alpha")) {
          header->ec_types.push_back(JXL_CHANNEL_ALPHA);
        } else if (MatchString("Depth")) {
          header->ec_types.push_back(JXL_CHANNEL_DEPTH);
        } else if (MatchString("SpotColor")) {
          header->ec_types.push_back(JXL_CHANNEL_SPOT_COLOR);
        } else if (MatchString("SelectionMask")) {
          header->ec_types.push_back(JXL_CHANNEL_SELECTION_MASK);
        } else if (MatchString("Black")) {
          header->ec_types.push_back(JXL_CHANNEL_BLACK);
        } else if (MatchString("CFA")) {
          header->ec_types.push_back(JXL_CHANNEL_CFA);
        } else if (MatchString("Thermal")) {
          header->ec_types.push_back(JXL_CHANNEL_THERMAL);
        } else {
          return JXL_FAILURE("PAM: unknown TUPLTYPE");
        }
      } else {
        constexpr size_t kMaxHeaderLength = 20;
        char unknown_header[kMaxHeaderLength + 1];
        size_t len = std::min<size_t>(kMaxHeaderLength, end_ - pos_);
        strncpy(unknown_header, reinterpret_cast<const char*>(pos_), len);
        unknown_header[len] = 0;
        return JXL_FAILURE("PAM: unknown header keyword: %s", unknown_header);
      }
    }
    size_t num_channels = header->is_gray ? 1 : 3;
    if (header->has_alpha) num_channels++;
    if (num_channels + header->ec_types.size() != depth) {
      return JXL_FAILURE("PAM: bad DEPTH");
    }
    if (max_val == 0 || max_val >= 65536) {
      return JXL_FAILURE("PAM: bad MAXVAL");
    }
    // e.g. When `max_val` is 1 , we want 1 bit:
    header->bits_per_sample = FloorLog2Nonzero(max_val) + 1;
    if ((1u << header->bits_per_sample) - 1 != max_val)
      return JXL_FAILURE("PNM: unsupported MaxVal (expected 2^n - 1)");
    // PAM does not pack bits as in PBM.

    header->floating_point = false;
    header->big_endian = true;
    *pos = pos_;
    return true;
  }

  Status ParseHeaderPNM(HeaderPNM* header, const uint8_t** pos) {
    JXL_RETURN_IF_ERROR(SkipWhitespace());
    JXL_RETURN_IF_ERROR(ParseUnsigned(&header->xsize));

    JXL_RETURN_IF_ERROR(SkipWhitespace());
    JXL_RETURN_IF_ERROR(ParseUnsigned(&header->ysize));

    JXL_RETURN_IF_ERROR(SkipWhitespace());
    size_t max_val;
    JXL_RETURN_IF_ERROR(ParseUnsigned(&max_val));
    if (max_val == 0 || max_val >= 65536) {
      return JXL_FAILURE("PNM: bad MaxVal");
    }
    header->bits_per_sample = FloorLog2Nonzero(max_val) + 1;
    if ((1u << header->bits_per_sample) - 1 != max_val)
      return JXL_FAILURE("PNM: unsupported MaxVal (expected 2^n - 1)");
    header->floating_point = false;
    header->big_endian = true;

    JXL_RETURN_IF_ERROR(SkipSingleWhitespace());

    *pos = pos_;
    return true;
  }

  Status ParseHeaderPFM(HeaderPNM* header, const uint8_t** pos) {
    JXL_RETURN_IF_ERROR(SkipSingleWhitespace());
    JXL_RETURN_IF_ERROR(ParseUnsigned(&header->xsize));

    JXL_RETURN_IF_ERROR(SkipBlank());
    JXL_RETURN_IF_ERROR(ParseUnsigned(&header->ysize));

    JXL_RETURN_IF_ERROR(SkipSingleWhitespace());
    // The scale has no meaning as multiplier, only its sign is used to
    // indicate endianness. All software expects nominal range 0..1.
    double scale;
    JXL_RETURN_IF_ERROR(ParseSigned(&scale));
    if (scale == 0.0) {
      return JXL_FAILURE("PFM: bad scale factor value.");
    } else if (std::abs(scale) != 1.0) {
      JXL_WARNING("PFM: Discarding non-unit scale factor");
    }
    header->big_endian = scale > 0.0;
    header->bits_per_sample = 32;
    header->floating_point = true;

    JXL_RETURN_IF_ERROR(SkipSingleWhitespace());

    *pos = pos_;
    return true;
  }

  const uint8_t* pos_;
  const uint8_t* const end_;
};

Span<const uint8_t> MakeSpan(const char* str) {
  return Span<const uint8_t>(reinterpret_cast<const uint8_t*>(str),
                             strlen(str));
}

}  // namespace

Status DecodeImagePNM(const Span<const uint8_t> bytes,
                      const ColorHints& color_hints, PackedPixelFile* ppf,
                      const SizeConstraints* constraints) {
  Parser parser(bytes);
  HeaderPNM header = {};
  const uint8_t* pos = nullptr;
  if (!parser.ParseHeader(&header, &pos)) return false;
  JXL_RETURN_IF_ERROR(
      VerifyDimensions(constraints, header.xsize, header.ysize));

  if (header.bits_per_sample == 0 || header.bits_per_sample > 32) {
    return JXL_FAILURE("PNM: bits_per_sample invalid");
  }

  // PPM specify that in the raster, the sample values are "nonlinear" (BP.709,
  // with gamma number of 2.2). Deviate from the specification and assume
  // `sRGB` in our implementation.
  JXL_RETURN_IF_ERROR(ApplyColorHints(color_hints, /*color_already_set=*/false,
                                      header.is_gray, ppf));

  ppf->info.xsize = header.xsize;
  ppf->info.ysize = header.ysize;
  if (header.floating_point) {
    ppf->info.bits_per_sample = 32;
    ppf->info.exponent_bits_per_sample = 8;
  } else {
    ppf->info.bits_per_sample = header.bits_per_sample;
    ppf->info.exponent_bits_per_sample = 0;
  }

  ppf->info.orientation = JXL_ORIENT_IDENTITY;

  // No alpha in PNM and PFM
  ppf->info.alpha_bits = (header.has_alpha ? ppf->info.bits_per_sample : 0);
  ppf->info.alpha_exponent_bits = 0;
  ppf->info.num_color_channels = (header.is_gray ? 1 : 3);
  uint32_t num_alpha_channels = (header.has_alpha ? 1 : 0);
  uint32_t num_interleaved_channels =
      ppf->info.num_color_channels + num_alpha_channels;
  ppf->info.num_extra_channels = num_alpha_channels + header.ec_types.size();

  for (auto type : header.ec_types) {
    PackedExtraChannel pec;
    pec.ec_info.bits_per_sample = ppf->info.bits_per_sample;
    pec.ec_info.type = type;
    ppf->extra_channels_info.emplace_back(std::move(pec));
  }

  JxlDataType data_type;
  if (header.floating_point) {
    // There's no float16 pnm version.
    data_type = JXL_TYPE_FLOAT;
  } else {
    if (header.bits_per_sample > 8) {
      data_type = JXL_TYPE_UINT16;
    } else {
      data_type = JXL_TYPE_UINT8;
    }
  }

  const JxlPixelFormat format{
      /*num_channels=*/num_interleaved_channels,
      /*data_type=*/data_type,
      /*endianness=*/header.big_endian ? JXL_BIG_ENDIAN : JXL_LITTLE_ENDIAN,
      /*align=*/0,
  };
  const JxlPixelFormat ec_format{1, format.data_type, format.endianness, 0};
  ppf->frames.clear();
  ppf->frames.emplace_back(header.xsize, header.ysize, format);
  auto* frame = &ppf->frames.back();
  for (size_t i = 0; i < header.ec_types.size(); ++i) {
    frame->extra_channels.emplace_back(header.xsize, header.ysize, ec_format);
  }
  size_t pnm_remaining_size = bytes.data() + bytes.size() - pos;
  if (pnm_remaining_size < frame->color.pixels_size) {
    return JXL_FAILURE("PNM file too small");
  }

  uint8_t* out = reinterpret_cast<uint8_t*>(frame->color.pixels());
  std::vector<uint8_t*> ec_out(header.ec_types.size());
  for (size_t i = 0; i < ec_out.size(); ++i) {
    ec_out[i] = reinterpret_cast<uint8_t*>(frame->extra_channels[i].pixels());
  }
  if (ec_out.empty()) {
    const bool flipped_y = header.bits_per_sample == 32;  // PFMs are flipped
    for (size_t y = 0; y < header.ysize; ++y) {
      size_t y_in = flipped_y ? header.ysize - 1 - y : y;
      const uint8_t* row_in = &pos[y_in * frame->color.stride];
      uint8_t* row_out = &out[y * frame->color.stride];
      memcpy(row_out, row_in, frame->color.stride);
    }
  } else {
    size_t pwidth = PackedImage::BitsPerChannel(data_type) / 8;
    for (size_t y = 0; y < header.ysize; ++y) {
      for (size_t x = 0; x < header.xsize; ++x) {
        memcpy(out, pos, frame->color.pixel_stride());
        out += frame->color.pixel_stride();
        pos += frame->color.pixel_stride();
        for (auto& p : ec_out) {
          memcpy(p, pos, pwidth);
          pos += pwidth;
          p += pwidth;
        }
      }
    }
  }
  return true;
}

void TestCodecPNM() {
  size_t u = 77777;  // Initialized to wrong value.
  double d = 77.77;
// Failing to parse invalid strings results in a crash if `JXL_CRASH_ON_ERROR`
// is defined and hence the tests fail. Therefore we only run these tests if
// `JXL_CRASH_ON_ERROR` is not defined.
#ifndef JXL_CRASH_ON_ERROR
  JXL_CHECK(false == Parser(MakeSpan("")).ParseUnsigned(&u));
  JXL_CHECK(false == Parser(MakeSpan("+")).ParseUnsigned(&u));
  JXL_CHECK(false == Parser(MakeSpan("-")).ParseUnsigned(&u));
  JXL_CHECK(false == Parser(MakeSpan("A")).ParseUnsigned(&u));

  JXL_CHECK(false == Parser(MakeSpan("")).ParseSigned(&d));
  JXL_CHECK(false == Parser(MakeSpan("+")).ParseSigned(&d));
  JXL_CHECK(false == Parser(MakeSpan("-")).ParseSigned(&d));
  JXL_CHECK(false == Parser(MakeSpan("A")).ParseSigned(&d));
#endif
  JXL_CHECK(true == Parser(MakeSpan("1")).ParseUnsigned(&u));
  JXL_CHECK(u == 1);

  JXL_CHECK(true == Parser(MakeSpan("32")).ParseUnsigned(&u));
  JXL_CHECK(u == 32);

  JXL_CHECK(true == Parser(MakeSpan("1")).ParseSigned(&d));
  JXL_CHECK(d == 1.0);
  JXL_CHECK(true == Parser(MakeSpan("+2")).ParseSigned(&d));
  JXL_CHECK(d == 2.0);
  JXL_CHECK(true == Parser(MakeSpan("-3")).ParseSigned(&d));
  JXL_CHECK(std::abs(d - -3.0) < 1E-15);
  JXL_CHECK(true == Parser(MakeSpan("3.141592")).ParseSigned(&d));
  JXL_CHECK(std::abs(d - 3.141592) < 1E-15);
  JXL_CHECK(true == Parser(MakeSpan("-3.141592")).ParseSigned(&d));
  JXL_CHECK(std::abs(d - -3.141592) < 1E-15);
}

}  // namespace extras
}  // namespace jxl
