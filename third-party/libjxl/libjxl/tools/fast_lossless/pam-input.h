// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <limits.h>
#include <stdlib.h>
#include <string.h>

bool error_msg(const char* message) {
  fprintf(stderr, "%s\n", message);
  return false;
}
#define return_on_error(X) \
  if (!X) return false;

size_t Log2(uint32_t value) { return 31 - __builtin_clz(value); }

struct HeaderPNM {
  size_t xsize;
  size_t ysize;
  bool is_gray;    // PGM
  bool has_alpha;  // PAM
  size_t bits_per_sample;
};

class Parser {
 public:
  explicit Parser(uint8_t* data, size_t length)
      : pos_(data), end_(data + length) {}

  // Sets "pos" to the first non-header byte/pixel on success.
  bool ParseHeader(HeaderPNM* header, const uint8_t** pos) {
    // codec.cc ensures we have at least two bytes => no range check here.
    if (pos_[0] != 'P') return false;
    const uint8_t type = pos_[1];
    pos_ += 2;

    switch (type) {
      case '5':
        header->is_gray = true;
        return ParseHeaderPNM(header, pos);

      case '6':
        header->is_gray = false;
        return ParseHeaderPNM(header, pos);

      case '7':
        return ParseHeaderPAM(header, pos);
    }
    return false;
  }

  // Exposed for testing
  bool ParseUnsigned(size_t* number) {
    if (pos_ == end_) return error_msg("PNM: reached end before number");
    if (!IsDigit(*pos_)) return error_msg("PNM: expected unsigned number");

    *number = 0;
    while (pos_ < end_ && *pos_ >= '0' && *pos_ <= '9') {
      *number *= 10;
      *number += *pos_ - '0';
      ++pos_;
    }

    return true;
  }

  bool ParseSigned(double* number) {
    if (pos_ == end_) return error_msg("PNM: reached end before signed");

    if (*pos_ != '-' && *pos_ != '+' && !IsDigit(*pos_)) {
      return error_msg("PNM: expected signed number");
    }

    // Skip sign
    const bool is_neg = *pos_ == '-';
    if (is_neg || *pos_ == '+') {
      ++pos_;
      if (pos_ == end_) return error_msg("PNM: reached end before digits");
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

  bool SkipBlank() {
    if (pos_ == end_) return error_msg("PNM: reached end before blank");
    const uint8_t c = *pos_;
    if (c != ' ' && c != '\n') return error_msg("PNM: expected blank");
    ++pos_;
    return true;
  }

  bool SkipSingleWhitespace() {
    if (pos_ == end_) return error_msg("PNM: reached end before whitespace");
    if (!IsWhitespace(*pos_)) return error_msg("PNM: expected whitespace");
    ++pos_;
    return true;
  }

  bool SkipWhitespace() {
    if (pos_ == end_) return error_msg("PNM: reached end before whitespace");
    if (!IsWhitespace(*pos_) && *pos_ != '#') {
      return error_msg("PNM: expected whitespace/comment");
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

  bool MatchString(const char* keyword) {
    const uint8_t* ppos = pos_;
    while (*keyword) {
      if (ppos >= end_) return error_msg("PAM: unexpected end of input");
      if (*keyword != *ppos) return false;
      ppos++;
      keyword++;
    }
    pos_ = ppos;
    return_on_error(SkipWhitespace());
    return true;
  }

  bool ParseHeaderPAM(HeaderPNM* header, const uint8_t** pos) {
    size_t num_channels = 3;
    size_t max_val = 255;
    while (!MatchString("ENDHDR")) {
      return_on_error(SkipWhitespace());
      if (MatchString("WIDTH")) {
        return_on_error(ParseUnsigned(&header->xsize));
      } else if (MatchString("HEIGHT")) {
        return_on_error(ParseUnsigned(&header->ysize));
      } else if (MatchString("DEPTH")) {
        return_on_error(ParseUnsigned(&num_channels));
      } else if (MatchString("MAXVAL")) {
        return_on_error(ParseUnsigned(&max_val));
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
        } else {
          return error_msg("PAM: unknown TUPLTYPE");
        }
      } else {
        return error_msg("PAM: unknown header keyword");
      }
    }
    if (num_channels !=
        (header->has_alpha ? 1 : 0) + (header->is_gray ? 1 : 3)) {
      return error_msg("PAM: bad DEPTH");
    }
    if (max_val == 0 || max_val >= 65536) {
      return error_msg("PAM: bad MAXVAL");
    }
    header->bits_per_sample = Log2(max_val + 1);

    *pos = pos_;
    return true;
  }

  bool ParseHeaderPNM(HeaderPNM* header, const uint8_t** pos) {
    return_on_error(SkipWhitespace());
    return_on_error(ParseUnsigned(&header->xsize));

    return_on_error(SkipWhitespace());
    return_on_error(ParseUnsigned(&header->ysize));

    return_on_error(SkipWhitespace());
    size_t max_val;
    return_on_error(ParseUnsigned(&max_val));
    if (max_val == 0 || max_val >= 65536) {
      return error_msg("PNM: bad MaxVal");
    }
    header->bits_per_sample = Log2(max_val + 1);

    return_on_error(SkipSingleWhitespace());

    *pos = pos_;
    return true;
  }

  const uint8_t* pos_;
  const uint8_t* const end_;
};

bool load_file(unsigned char** out, size_t* outsize, const char* filename) {
  FILE* file;
  file = fopen(filename, "rb");
  if (!file) return false;
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return false;
  }
  *outsize = ftell(file);
  if (*outsize == LONG_MAX || *outsize < 9 || fseek(file, 0, SEEK_SET)) {
    fclose(file);
    return false;
  }
  *out = (unsigned char*)malloc(*outsize);
  if (!(*out)) {
    fclose(file);
    return false;
  }
  size_t readsize;
  readsize = fread(*out, 1, *outsize, file);
  fclose(file);
  if (readsize != *outsize) return false;
  return true;
}

bool DecodePAM(const char* filename, uint8_t** buffer, size_t* w, size_t* h,
               size_t* nb_chans, size_t* bitdepth) {
  unsigned char* in_file;
  size_t in_size;
  if (!load_file(&in_file, &in_size, filename))
    return error_msg("Could not read input file");
  Parser parser(in_file, in_size);
  HeaderPNM header = {};
  const uint8_t* pos = nullptr;
  if (!parser.ParseHeader(&header, &pos)) return false;

  if (header.bits_per_sample == 0 || header.bits_per_sample > 16) {
    return error_msg("PNM: bits_per_sample invalid (can do at most 16-bit)");
  }
  *w = header.xsize;
  *h = header.ysize;
  *bitdepth = header.bits_per_sample;
  *nb_chans = (header.is_gray ? 1 : 3) + (header.has_alpha ? 1 : 0);

  size_t pnm_remaining_size = in_file + in_size - pos;
  size_t buffer_size = *w * *h * *nb_chans * (*bitdepth > 8 ? 2 : 1);
  if (pnm_remaining_size < buffer_size) {
    return error_msg("PNM file too small");
  }
  *buffer = (uint8_t*)malloc(buffer_size);
  memcpy(*buffer, pos, buffer_size);
  return true;
}
