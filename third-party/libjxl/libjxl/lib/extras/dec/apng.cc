// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/dec/apng.h"

// Parts of this code are taken from apngdis, which has the following license:
/* APNG Disassembler 2.8
 *
 * Deconstructs APNG files into individual frames.
 *
 * http://apngdis.sourceforge.net
 *
 * Copyright (c) 2010-2015 Max Stepin
 * maxst at users.sourceforge.net
 *
 * zlib license
 * ------------
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 */

#include <jxl/codestream_header.h>
#include <jxl/encode.h>
#include <stdio.h>
#include <string.h>

#include <string>
#include <utility>
#include <vector>

#include "lib/extras/size_constraints.h"
#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/scope_guard.h"
#include "lib/jxl/common.h"
#include "lib/jxl/sanitizers.h"
#if JPEGXL_ENABLE_APNG
#include "png.h" /* original (unpatched) libpng is ok */
#endif

namespace jxl {
namespace extras {

#if JPEGXL_ENABLE_APNG
namespace {

constexpr unsigned char kExifSignature[6] = {0x45, 0x78, 0x69,
                                             0x66, 0x00, 0x00};

/* hIST chunk tail is not proccesed properly; skip this chunk completely;
   see https://github.com/glennrp/libpng/pull/413 */
const png_byte kIgnoredPngChunks[] = {
    104, 73, 83, 84, '\0' /* hIST */
};

// Returns floating-point value from the PNG encoding (times 10^5).
static double F64FromU32(const uint32_t x) {
  return static_cast<int32_t>(x) * 1E-5;
}

Status DecodeSRGB(const unsigned char* payload, const size_t payload_size,
                  JxlColorEncoding* color_encoding) {
  if (payload_size != 1) return JXL_FAILURE("Wrong sRGB size");
  // (PNG uses the same values as ICC.)
  if (payload[0] >= 4) return JXL_FAILURE("Invalid Rendering Intent");
  color_encoding->white_point = JXL_WHITE_POINT_D65;
  color_encoding->primaries = JXL_PRIMARIES_SRGB;
  color_encoding->transfer_function = JXL_TRANSFER_FUNCTION_SRGB;
  color_encoding->rendering_intent =
      static_cast<JxlRenderingIntent>(payload[0]);
  return true;
}

// If the cICP profile is not fully supported, return false and leave
// color_encoding unmodified.
Status DecodeCICP(const unsigned char* payload, const size_t payload_size,
                  JxlColorEncoding* color_encoding) {
  if (payload_size != 4) return JXL_FAILURE("Wrong cICP size");
  JxlColorEncoding color_enc = *color_encoding;

  // From https://www.itu.int/rec/T-REC-H.273-202107-I/en
  if (payload[0] == 1) {
    // IEC 61966-2-1 sRGB
    color_enc.primaries = JXL_PRIMARIES_SRGB;
    color_enc.white_point = JXL_WHITE_POINT_D65;
  } else if (payload[0] == 4) {
    // Rec. ITU-R BT.470-6 System M
    color_enc.primaries = JXL_PRIMARIES_CUSTOM;
    color_enc.primaries_red_xy[0] = 0.67;
    color_enc.primaries_red_xy[1] = 0.33;
    color_enc.primaries_green_xy[0] = 0.21;
    color_enc.primaries_green_xy[1] = 0.71;
    color_enc.primaries_blue_xy[0] = 0.14;
    color_enc.primaries_blue_xy[1] = 0.08;
    color_enc.white_point = JXL_WHITE_POINT_CUSTOM;
    color_enc.white_point_xy[0] = 0.310;
    color_enc.white_point_xy[1] = 0.316;
  } else if (payload[0] == 5) {
    // Rec. ITU-R BT.1700-0 625 PAL and 625 SECAM
    color_enc.primaries = JXL_PRIMARIES_CUSTOM;
    color_enc.primaries_red_xy[0] = 0.64;
    color_enc.primaries_red_xy[1] = 0.33;
    color_enc.primaries_green_xy[0] = 0.29;
    color_enc.primaries_green_xy[1] = 0.60;
    color_enc.primaries_blue_xy[0] = 0.15;
    color_enc.primaries_blue_xy[1] = 0.06;
    color_enc.white_point = JXL_WHITE_POINT_D65;
  } else if (payload[0] == 6 || payload[0] == 7) {
    // SMPTE ST 170 (2004) / SMPTE ST 240 (1999)
    color_enc.primaries = JXL_PRIMARIES_CUSTOM;
    color_enc.primaries_red_xy[0] = 0.630;
    color_enc.primaries_red_xy[1] = 0.340;
    color_enc.primaries_green_xy[0] = 0.310;
    color_enc.primaries_green_xy[1] = 0.595;
    color_enc.primaries_blue_xy[0] = 0.155;
    color_enc.primaries_blue_xy[1] = 0.070;
    color_enc.white_point = JXL_WHITE_POINT_D65;
  } else if (payload[0] == 8) {
    // Generic film (colour filters using Illuminant C)
    color_enc.primaries = JXL_PRIMARIES_CUSTOM;
    color_enc.primaries_red_xy[0] = 0.681;
    color_enc.primaries_red_xy[1] = 0.319;
    color_enc.primaries_green_xy[0] = 0.243;
    color_enc.primaries_green_xy[1] = 0.692;
    color_enc.primaries_blue_xy[0] = 0.145;
    color_enc.primaries_blue_xy[1] = 0.049;
    color_enc.white_point = JXL_WHITE_POINT_CUSTOM;
    color_enc.white_point_xy[0] = 0.310;
    color_enc.white_point_xy[1] = 0.316;
  } else if (payload[0] == 9) {
    // Rec. ITU-R BT.2100-2
    color_enc.primaries = JXL_PRIMARIES_2100;
    color_enc.white_point = JXL_WHITE_POINT_D65;
  } else if (payload[0] == 10) {
    // CIE 1931 XYZ
    color_enc.primaries = JXL_PRIMARIES_CUSTOM;
    color_enc.primaries_red_xy[0] = 1;
    color_enc.primaries_red_xy[1] = 0;
    color_enc.primaries_green_xy[0] = 0;
    color_enc.primaries_green_xy[1] = 1;
    color_enc.primaries_blue_xy[0] = 0;
    color_enc.primaries_blue_xy[1] = 0;
    color_enc.white_point = JXL_WHITE_POINT_E;
  } else if (payload[0] == 11) {
    // SMPTE RP 431-2 (2011)
    color_enc.primaries = JXL_PRIMARIES_P3;
    color_enc.white_point = JXL_WHITE_POINT_DCI;
  } else if (payload[0] == 12) {
    // SMPTE EG 432-1 (2010)
    color_enc.primaries = JXL_PRIMARIES_P3;
    color_enc.white_point = JXL_WHITE_POINT_D65;
  } else if (payload[0] == 22) {
    color_enc.primaries = JXL_PRIMARIES_CUSTOM;
    color_enc.primaries_red_xy[0] = 0.630;
    color_enc.primaries_red_xy[1] = 0.340;
    color_enc.primaries_green_xy[0] = 0.295;
    color_enc.primaries_green_xy[1] = 0.605;
    color_enc.primaries_blue_xy[0] = 0.155;
    color_enc.primaries_blue_xy[1] = 0.077;
    color_enc.white_point = JXL_WHITE_POINT_D65;
  } else {
    JXL_WARNING("Unsupported primaries specified in cICP chunk: %d",
                static_cast<int>(payload[0]));
    return false;
  }

  if (payload[1] == 1 || payload[1] == 6 || payload[1] == 14 ||
      payload[1] == 15) {
    // Rec. ITU-R BT.709-6
    color_enc.transfer_function = JXL_TRANSFER_FUNCTION_709;
  } else if (payload[1] == 4) {
    // Rec. ITU-R BT.1700-0 625 PAL and 625 SECAM
    color_enc.transfer_function = JXL_TRANSFER_FUNCTION_GAMMA;
    color_enc.gamma = 1 / 2.2;
  } else if (payload[1] == 5) {
    // Rec. ITU-R BT.470-6 System B, G
    color_enc.transfer_function = JXL_TRANSFER_FUNCTION_GAMMA;
    color_enc.gamma = 1 / 2.8;
  } else if (payload[1] == 8 || payload[1] == 13 || payload[1] == 16 ||
             payload[1] == 17 || payload[1] == 18) {
    // These codes all match the corresponding JXL enum values
    color_enc.transfer_function = static_cast<JxlTransferFunction>(payload[1]);
  } else {
    JXL_WARNING("Unsupported transfer function specified in cICP chunk: %d",
                static_cast<int>(payload[1]));
    return false;
  }

  if (payload[2] != 0) {
    JXL_WARNING("Unsupported color space specified in cICP chunk: %d",
                static_cast<int>(payload[2]));
    return false;
  }
  if (payload[3] != 1) {
    JXL_WARNING("Unsupported full-range flag specified in cICP chunk: %d",
                static_cast<int>(payload[3]));
    return false;
  }
  // cICP has no rendering intent, so use the default
  color_enc.rendering_intent = JXL_RENDERING_INTENT_RELATIVE;
  *color_encoding = color_enc;
  return true;
}

Status DecodeGAMA(const unsigned char* payload, const size_t payload_size,
                  JxlColorEncoding* color_encoding) {
  if (payload_size != 4) return JXL_FAILURE("Wrong gAMA size");
  color_encoding->transfer_function = JXL_TRANSFER_FUNCTION_GAMMA;
  color_encoding->gamma = F64FromU32(LoadBE32(payload));
  return true;
}

Status DecodeCHRM(const unsigned char* payload, const size_t payload_size,
                  JxlColorEncoding* color_encoding) {
  if (payload_size != 32) return JXL_FAILURE("Wrong cHRM size");

  color_encoding->white_point = JXL_WHITE_POINT_CUSTOM;
  color_encoding->white_point_xy[0] = F64FromU32(LoadBE32(payload + 0));
  color_encoding->white_point_xy[1] = F64FromU32(LoadBE32(payload + 4));

  color_encoding->primaries = JXL_PRIMARIES_CUSTOM;
  color_encoding->primaries_red_xy[0] = F64FromU32(LoadBE32(payload + 8));
  color_encoding->primaries_red_xy[1] = F64FromU32(LoadBE32(payload + 12));
  color_encoding->primaries_green_xy[0] = F64FromU32(LoadBE32(payload + 16));
  color_encoding->primaries_green_xy[1] = F64FromU32(LoadBE32(payload + 20));
  color_encoding->primaries_blue_xy[0] = F64FromU32(LoadBE32(payload + 24));
  color_encoding->primaries_blue_xy[1] = F64FromU32(LoadBE32(payload + 28));
  return true;
}

// Retrieves XMP and EXIF/IPTC from itext and text.
class BlobsReaderPNG {
 public:
  static Status Decode(const png_text_struct& info, PackedMetadata* metadata) {
    // We trust these are properly null-terminated by libpng.
    const char* key = info.key;
    const char* value = info.text;
    if (strstr(key, "XML:com.adobe.xmp")) {
      metadata->xmp.resize(strlen(value));  // safe, see above
      memcpy(metadata->xmp.data(), value, metadata->xmp.size());
    }

    std::string type;
    std::vector<uint8_t> bytes;

    // Handle text chunks annotated with key "Raw profile type ####", with
    // #### a type, which may contain metadata.
    const char* kKey = "Raw profile type ";
    if (strncmp(key, kKey, strlen(kKey)) != 0) return false;

    if (!MaybeDecodeBase16(key, value, &type, &bytes)) {
      JXL_WARNING("Couldn't parse 'Raw format type' text chunk");
      return false;
    }
    if (type == "exif") {
      // Remove "Exif\0\0" prefix if present
      if (bytes.size() >= sizeof kExifSignature &&
          memcmp(bytes.data(), kExifSignature, sizeof kExifSignature) == 0) {
        bytes.erase(bytes.begin(), bytes.begin() + sizeof kExifSignature);
      }
      if (!metadata->exif.empty()) {
        JXL_WARNING("overwriting EXIF (%" PRIuS " bytes) with base16 (%" PRIuS
                    " bytes)",
                    metadata->exif.size(), bytes.size());
      }
      metadata->exif = std::move(bytes);
    } else if (type == "iptc") {
      // TODO (jon): Deal with IPTC in some way
    } else if (type == "8bim") {
      // TODO (jon): Deal with 8bim in some way
    } else if (type == "xmp") {
      if (!metadata->xmp.empty()) {
        JXL_WARNING("overwriting XMP (%" PRIuS " bytes) with base16 (%" PRIuS
                    " bytes)",
                    metadata->xmp.size(), bytes.size());
      }
      metadata->xmp = std::move(bytes);
    } else {
      JXL_WARNING("Unknown type in 'Raw format type' text chunk: %s: %" PRIuS
                  " bytes",
                  type.c_str(), bytes.size());
    }
    return true;
  }

 private:
  // Returns false if invalid.
  static JXL_INLINE Status DecodeNibble(const char c,
                                        uint32_t* JXL_RESTRICT nibble) {
    if ('a' <= c && c <= 'f') {
      *nibble = 10 + c - 'a';
    } else if ('0' <= c && c <= '9') {
      *nibble = c - '0';
    } else {
      *nibble = 0;
      return JXL_FAILURE("Invalid metadata nibble");
    }
    JXL_ASSERT(*nibble < 16);
    return true;
  }

  // Returns false if invalid.
  static JXL_INLINE Status DecodeDecimal(const char** pos, const char* end,
                                         uint32_t* JXL_RESTRICT value) {
    size_t len = 0;
    *value = 0;
    while (*pos < end) {
      char next = **pos;
      if (next >= '0' && next <= '9') {
        *value = (*value * 10) + static_cast<uint32_t>(next - '0');
        len++;
        if (len > 8) {
          break;
        }
      } else {
        // Do not consume terminator (non-decimal digit).
        break;
      }
      (*pos)++;
    }
    if (len == 0 || len > 8) {
      return JXL_FAILURE("Failed to parse decimal");
    }
    return true;
  }

  // Parses a PNG text chunk with key of the form "Raw profile type ####", with
  // #### a type.
  // Returns whether it could successfully parse the content.
  // We trust key and encoded are null-terminated because they come from
  // libpng.
  static Status MaybeDecodeBase16(const char* key, const char* encoded,
                                  std::string* type,
                                  std::vector<uint8_t>* bytes) {
    const char* encoded_end = encoded + strlen(encoded);

    const char* kKey = "Raw profile type ";
    if (strncmp(key, kKey, strlen(kKey)) != 0) return false;
    *type = key + strlen(kKey);
    const size_t kMaxTypeLen = 20;
    if (type->length() > kMaxTypeLen) return false;  // Type too long

    // Header: freeform string and number of bytes
    // Expected format is:
    // \n
    // profile name/description\n
    //       40\n               (the number of bytes after hex-decoding)
    // 01234566789abcdef....\n  (72 bytes per line max).
    // 012345667\n              (last line)
    const char* pos = encoded;

    if (*(pos++) != '\n') return false;
    while (pos < encoded_end && *pos != '\n') {
      pos++;
    }
    if (pos == encoded_end) return false;
    // We parsed so far a \n, some number of non \n characters and are now
    // pointing at a \n.
    if (*(pos++) != '\n') return false;
    // Skip leading spaces
    while (pos < encoded_end && *pos == ' ') {
      pos++;
    }
    uint32_t bytes_to_decode = 0;
    JXL_RETURN_IF_ERROR(DecodeDecimal(&pos, encoded_end, &bytes_to_decode));

    // We need 2*bytes for the hex values plus 1 byte every 36 values,
    // plus terminal \n for length.
    const unsigned long needed_bytes =
        bytes_to_decode * 2 + 1 + DivCeil(bytes_to_decode, 36);
    if (needed_bytes != static_cast<size_t>(encoded_end - pos)) {
      return JXL_FAILURE("Not enough bytes to parse %d bytes in hex",
                         bytes_to_decode);
    }
    JXL_ASSERT(bytes->empty());
    bytes->reserve(bytes_to_decode);

    // Encoding: base16 with newline after 72 chars.
    // pos points to the \n before the first line of hex values.
    for (size_t i = 0; i < bytes_to_decode; ++i) {
      if (i % 36 == 0) {
        if (pos + 1 >= encoded_end) return false;  // Truncated base16 1
        if (*pos != '\n') return false;            // Expected newline
        ++pos;
      }

      if (pos + 2 >= encoded_end) return false;  // Truncated base16 2;
      uint32_t nibble0, nibble1;
      JXL_RETURN_IF_ERROR(DecodeNibble(pos[0], &nibble0));
      JXL_RETURN_IF_ERROR(DecodeNibble(pos[1], &nibble1));
      bytes->push_back(static_cast<uint8_t>((nibble0 << 4) + nibble1));
      pos += 2;
    }
    if (pos + 1 != encoded_end) return false;  // Too many encoded bytes
    if (pos[0] != '\n') return false;          // Incorrect metadata terminator
    return true;
  }
};

constexpr bool isAbc(char c) {
  return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
}

constexpr uint32_t kId_IHDR = 0x52444849;
constexpr uint32_t kId_acTL = 0x4C546361;
constexpr uint32_t kId_fcTL = 0x4C546366;
constexpr uint32_t kId_IDAT = 0x54414449;
constexpr uint32_t kId_fdAT = 0x54416466;
constexpr uint32_t kId_IEND = 0x444E4549;
constexpr uint32_t kId_cICP = 0x50434963;
constexpr uint32_t kId_iCCP = 0x50434369;
constexpr uint32_t kId_sRGB = 0x42475273;
constexpr uint32_t kId_gAMA = 0x414D4167;
constexpr uint32_t kId_cHRM = 0x4D524863;
constexpr uint32_t kId_eXIf = 0x66495865;

struct APNGFrame {
  std::vector<uint8_t> pixels;
  std::vector<uint8_t*> rows;
  unsigned int w, h, delay_num, delay_den;
};

struct Reader {
  const uint8_t* next;
  const uint8_t* last;
  bool Read(void* data, size_t len) {
    size_t cap = last - next;
    size_t to_copy = std::min(cap, len);
    memcpy(data, next, to_copy);
    next += to_copy;
    return (len == to_copy);
  }
  bool Eof() { return next == last; }
};

const unsigned long cMaxPNGSize = 1000000UL;
const size_t kMaxPNGChunkSize = 1lu << 30;  // 1 GB

void info_fn(png_structp png_ptr, png_infop info_ptr) {
  png_set_expand(png_ptr);
  png_set_palette_to_rgb(png_ptr);
  png_set_tRNS_to_alpha(png_ptr);
  (void)png_set_interlace_handling(png_ptr);
  png_read_update_info(png_ptr, info_ptr);
}

void row_fn(png_structp png_ptr, png_bytep new_row, png_uint_32 row_num,
            int pass) {
  APNGFrame* frame = (APNGFrame*)png_get_progressive_ptr(png_ptr);
  JXL_CHECK(frame);
  JXL_CHECK(row_num < frame->rows.size());
  JXL_CHECK(frame->rows[row_num] < frame->pixels.data() + frame->pixels.size());
  png_progressive_combine_row(png_ptr, frame->rows[row_num], new_row);
}

inline unsigned int read_chunk(Reader* r, std::vector<uint8_t>* pChunk) {
  unsigned char len[4];
  if (r->Read(&len, 4)) {
    const auto size = png_get_uint_32(len);
    // Check first, to avoid overflow.
    if (size > kMaxPNGChunkSize) {
      JXL_WARNING("APNG chunk size is too big");
      return 0;
    }
    pChunk->resize(size + 12);
    memcpy(pChunk->data(), len, 4);
    if (r->Read(pChunk->data() + 4, pChunk->size() - 4)) {
      return LoadLE32(pChunk->data() + 4);
    }
  }
  return 0;
}

int processing_start(png_structp& png_ptr, png_infop& info_ptr, void* frame_ptr,
                     bool hasInfo, std::vector<uint8_t>& chunkIHDR,
                     std::vector<std::vector<uint8_t>>& chunksInfo) {
  unsigned char header[8] = {137, 80, 78, 71, 13, 10, 26, 10};

  // Cleanup prior decoder, if any.
  png_destroy_read_struct(&png_ptr, &info_ptr, 0);
  // Just in case. Not all versions on libpng wipe-out the pointers.
  png_ptr = nullptr;
  info_ptr = nullptr;

  png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  info_ptr = png_create_info_struct(png_ptr);
  if (!png_ptr || !info_ptr) return 1;

  if (setjmp(png_jmpbuf(png_ptr))) {
    return 1;
  }

  png_set_keep_unknown_chunks(png_ptr, 1, kIgnoredPngChunks,
                              (int)sizeof(kIgnoredPngChunks) / 5);

  png_set_crc_action(png_ptr, PNG_CRC_QUIET_USE, PNG_CRC_QUIET_USE);
  png_set_progressive_read_fn(png_ptr, frame_ptr, info_fn, row_fn, NULL);

  png_process_data(png_ptr, info_ptr, header, 8);
  png_process_data(png_ptr, info_ptr, chunkIHDR.data(), chunkIHDR.size());

  if (hasInfo) {
    for (unsigned int i = 0; i < chunksInfo.size(); i++) {
      png_process_data(png_ptr, info_ptr, chunksInfo[i].data(),
                       chunksInfo[i].size());
    }
  }
  return 0;
}

int processing_data(png_structp png_ptr, png_infop info_ptr, unsigned char* p,
                    unsigned int size) {
  if (!png_ptr || !info_ptr) return 1;

  if (setjmp(png_jmpbuf(png_ptr))) {
    return 1;
  }

  png_process_data(png_ptr, info_ptr, p, size);
  return 0;
}

int processing_finish(png_structp png_ptr, png_infop info_ptr,
                      PackedMetadata* metadata) {
  unsigned char footer[12] = {0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130};

  if (!png_ptr || !info_ptr) return 1;

  if (setjmp(png_jmpbuf(png_ptr))) {
    return 1;
  }

  png_process_data(png_ptr, info_ptr, footer, 12);
  // before destroying: check if we encountered any metadata chunks
  png_textp text_ptr;
  int num_text;
  png_get_text(png_ptr, info_ptr, &text_ptr, &num_text);
  for (int i = 0; i < num_text; i++) {
    (void)BlobsReaderPNG::Decode(text_ptr[i], metadata);
  }

  return 0;
}

}  // namespace
#endif

bool CanDecodeAPNG() {
#if JPEGXL_ENABLE_APNG
  return true;
#else
  return false;
#endif
}

Status DecodeImageAPNG(const Span<const uint8_t> bytes,
                       const ColorHints& color_hints, PackedPixelFile* ppf,
                       const SizeConstraints* constraints) {
#if JPEGXL_ENABLE_APNG
  Reader r;
  unsigned int id, j, w, h, w0, h0, x0, y0;
  unsigned int delay_num, delay_den, dop, bop, rowbytes, imagesize;
  unsigned char sig[8];
  png_structp png_ptr = nullptr;
  png_infop info_ptr = nullptr;
  std::vector<uint8_t> chunk;
  std::vector<uint8_t> chunkIHDR;
  std::vector<std::vector<uint8_t>> chunksInfo;
  bool isAnimated = false;
  bool hasInfo = false;
  bool seenFctl = false;
  APNGFrame frameRaw = {};
  uint32_t num_channels;
  JxlPixelFormat format;
  unsigned int bytes_per_pixel = 0;

  struct FrameInfo {
    PackedImage data;
    uint32_t duration;
    size_t x0, xsize;
    size_t y0, ysize;
    uint32_t dispose_op;
    uint32_t blend_op;
  };

  std::vector<FrameInfo> frames;

  // Make sure png memory is released in any case.
  auto scope_guard = MakeScopeGuard([&]() {
    png_destroy_read_struct(&png_ptr, &info_ptr, 0);
    // Just in case. Not all versions on libpng wipe-out the pointers.
    png_ptr = nullptr;
    info_ptr = nullptr;
  });

  r = {bytes.data(), bytes.data() + bytes.size()};
  // Not a PNG => not an error
  unsigned char png_signature[8] = {137, 80, 78, 71, 13, 10, 26, 10};
  if (!r.Read(sig, 8) || memcmp(sig, png_signature, 8) != 0) {
    return false;
  }
  id = read_chunk(&r, &chunkIHDR);

  ppf->info.exponent_bits_per_sample = 0;
  ppf->info.alpha_exponent_bits = 0;
  ppf->info.orientation = JXL_ORIENT_IDENTITY;

  ppf->frames.clear();

  bool have_color = false;
  bool have_cicp = false, have_iccp = false, have_srgb = false;
  bool errorstate = true;
  if (id == kId_IHDR && chunkIHDR.size() == 25) {
    x0 = 0;
    y0 = 0;
    delay_num = 1;
    delay_den = 10;
    dop = 0;
    bop = 0;

    w0 = w = png_get_uint_32(chunkIHDR.data() + 8);
    h0 = h = png_get_uint_32(chunkIHDR.data() + 12);
    if (w > cMaxPNGSize || h > cMaxPNGSize) {
      return false;
    }

    // default settings in case e.g. only gAMA is given
    ppf->color_encoding.color_space = JXL_COLOR_SPACE_RGB;
    ppf->color_encoding.white_point = JXL_WHITE_POINT_D65;
    ppf->color_encoding.primaries = JXL_PRIMARIES_SRGB;
    ppf->color_encoding.transfer_function = JXL_TRANSFER_FUNCTION_SRGB;
    ppf->color_encoding.rendering_intent = JXL_RENDERING_INTENT_RELATIVE;

    if (!processing_start(png_ptr, info_ptr, (void*)&frameRaw, hasInfo,
                          chunkIHDR, chunksInfo)) {
      while (!r.Eof()) {
        id = read_chunk(&r, &chunk);
        if (!id) break;
        seenFctl |= (id == kId_fcTL);

        if (id == kId_acTL && !hasInfo && !isAnimated) {
          isAnimated = true;
          ppf->info.have_animation = true;
          ppf->info.animation.tps_numerator = 1000;
          ppf->info.animation.tps_denominator = 1;
        } else if (id == kId_IEND ||
                   (id == kId_fcTL && (!hasInfo || isAnimated))) {
          if (hasInfo) {
            if (!processing_finish(png_ptr, info_ptr, &ppf->metadata)) {
              // Allocates the frame buffer.
              uint32_t duration = delay_num * 1000 / delay_den;
              frames.push_back(FrameInfo{PackedImage(w0, h0, format), duration,
                                         x0, w0, y0, h0, dop, bop});
              auto& frame = frames.back().data;
              for (size_t y = 0; y < h0; ++y) {
                memcpy(static_cast<uint8_t*>(frame.pixels()) + frame.stride * y,
                       frameRaw.rows[y], bytes_per_pixel * w0);
              }
            } else {
              break;
            }
          }

          if (id == kId_IEND) {
            errorstate = false;
            break;
          }
          if (chunk.size() < 34) {
            return JXL_FAILURE("Received a chunk that is too small (%" PRIuS
                               "B)",
                               chunk.size());
          }
          // At this point the old frame is done. Let's start a new one.
          w0 = png_get_uint_32(chunk.data() + 12);
          h0 = png_get_uint_32(chunk.data() + 16);
          x0 = png_get_uint_32(chunk.data() + 20);
          y0 = png_get_uint_32(chunk.data() + 24);
          delay_num = png_get_uint_16(chunk.data() + 28);
          delay_den = png_get_uint_16(chunk.data() + 30);
          dop = chunk[32];
          bop = chunk[33];

          if (!delay_den) delay_den = 100;

          if (w0 > cMaxPNGSize || h0 > cMaxPNGSize || x0 > cMaxPNGSize ||
              y0 > cMaxPNGSize || x0 + w0 > w || y0 + h0 > h || dop > 2 ||
              bop > 1) {
            break;
          }

          if (hasInfo) {
            memcpy(chunkIHDR.data() + 8, chunk.data() + 12, 8);
            if (processing_start(png_ptr, info_ptr, (void*)&frameRaw, hasInfo,
                                 chunkIHDR, chunksInfo)) {
              break;
            }
          }
        } else if (id == kId_IDAT) {
          // First IDAT chunk means we now have all header info
          if (seenFctl) {
            // `fcTL` chunk must appear after all `IDAT` chunks
            return JXL_FAILURE("IDAT chunk after fcTL chunk");
          }
          hasInfo = true;
          JXL_CHECK(w == png_get_image_width(png_ptr, info_ptr));
          JXL_CHECK(h == png_get_image_height(png_ptr, info_ptr));
          int colortype = png_get_color_type(png_ptr, info_ptr);
          int png_bit_depth = png_get_bit_depth(png_ptr, info_ptr);
          ppf->info.bits_per_sample = png_bit_depth;
          png_color_8p sigbits = NULL;
          png_get_sBIT(png_ptr, info_ptr, &sigbits);
          if (colortype & 1) {
            // palette will actually be 8-bit regardless of the index bitdepth
            ppf->info.bits_per_sample = 8;
          }
          if (colortype & 2) {
            ppf->info.num_color_channels = 3;
            ppf->color_encoding.color_space = JXL_COLOR_SPACE_RGB;
            if (sigbits && sigbits->red == sigbits->green &&
                sigbits->green == sigbits->blue)
              ppf->info.bits_per_sample = sigbits->red;
          } else {
            ppf->info.num_color_channels = 1;
            ppf->color_encoding.color_space = JXL_COLOR_SPACE_GRAY;
            if (sigbits) ppf->info.bits_per_sample = sigbits->gray;
          }
          if (colortype & 4 ||
              png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS)) {
            ppf->info.alpha_bits = ppf->info.bits_per_sample;
            if (sigbits) {
              if (sigbits->alpha &&
                  sigbits->alpha != ppf->info.bits_per_sample) {
                return JXL_FAILURE("Unsupported alpha bit-depth");
              }
              ppf->info.alpha_bits = sigbits->alpha;
            }
          } else {
            ppf->info.alpha_bits = 0;
          }
          ppf->color_encoding.color_space =
              (ppf->info.num_color_channels == 1 ? JXL_COLOR_SPACE_GRAY
                                                 : JXL_COLOR_SPACE_RGB);
          ppf->info.xsize = w;
          ppf->info.ysize = h;
          JXL_RETURN_IF_ERROR(VerifyDimensions(constraints, w, h));
          num_channels =
              ppf->info.num_color_channels + (ppf->info.alpha_bits ? 1 : 0);
          format = {
              /*num_channels=*/num_channels,
              /*data_type=*/ppf->info.bits_per_sample > 8 ? JXL_TYPE_UINT16
                                                          : JXL_TYPE_UINT8,
              /*endianness=*/JXL_BIG_ENDIAN,
              /*align=*/0,
          };
          if (png_bit_depth > 8 && format.data_type == JXL_TYPE_UINT8) {
            png_set_strip_16(png_ptr);
          }
          bytes_per_pixel =
              num_channels * (format.data_type == JXL_TYPE_UINT16 ? 2 : 1);
          rowbytes = w * bytes_per_pixel;
          imagesize = h * rowbytes;
          frameRaw.pixels.resize(imagesize);
          frameRaw.rows.resize(h);
          for (j = 0; j < h; j++)
            frameRaw.rows[j] = frameRaw.pixels.data() + j * rowbytes;

          if (processing_data(png_ptr, info_ptr, chunk.data(), chunk.size())) {
            break;
          }
        } else if (id == kId_fdAT && isAnimated) {
          if (!hasInfo) {
            return JXL_FAILURE("fDAT chunk before iDAT");
          }
          png_save_uint_32(chunk.data() + 4, chunk.size() - 16);
          memcpy(chunk.data() + 8, "IDAT", 4);
          if (processing_data(png_ptr, info_ptr, chunk.data() + 4,
                              chunk.size() - 4)) {
            break;
          }
        } else if (id == kId_cICP) {
          // Color profile chunks: cICP has the highest priority, followed by
          // iCCP and sRGB (which shouldn't co-exist, but if they do, we use
          // iCCP), followed finally by gAMA and cHRM.
          if (DecodeCICP(chunk.data() + 8, chunk.size() - 12,
                         &ppf->color_encoding)) {
            have_cicp = true;
            have_color = true;
            ppf->icc.clear();
          }
        } else if (!have_cicp && id == kId_iCCP) {
          if (processing_data(png_ptr, info_ptr, chunk.data(), chunk.size())) {
            JXL_WARNING("Corrupt iCCP chunk");
            break;
          }

          // TODO(jon): catch special case of PQ and synthesize color encoding
          // in that case
          int compression_type;
          png_bytep profile;
          png_charp name;
          png_uint_32 proflen = 0;
          auto ok = png_get_iCCP(png_ptr, info_ptr, &name, &compression_type,
                                 &profile, &proflen);
          if (ok && proflen) {
            ppf->icc.assign(profile, profile + proflen);
            have_color = true;
            have_iccp = true;
          } else {
            // TODO(eustas): JXL_WARNING?
          }
        } else if (!have_cicp && !have_iccp && id == kId_sRGB) {
          JXL_RETURN_IF_ERROR(DecodeSRGB(chunk.data() + 8, chunk.size() - 12,
                                         &ppf->color_encoding));
          have_srgb = true;
          have_color = true;
        } else if (!have_cicp && !have_srgb && !have_iccp && id == kId_gAMA) {
          JXL_RETURN_IF_ERROR(DecodeGAMA(chunk.data() + 8, chunk.size() - 12,
                                         &ppf->color_encoding));
          have_color = true;
        } else if (!have_cicp && !have_srgb && !have_iccp && id == kId_cHRM) {
          JXL_RETURN_IF_ERROR(DecodeCHRM(chunk.data() + 8, chunk.size() - 12,
                                         &ppf->color_encoding));
          have_color = true;
        } else if (id == kId_eXIf) {
          ppf->metadata.exif.resize(chunk.size() - 12);
          memcpy(ppf->metadata.exif.data(), chunk.data() + 8,
                 chunk.size() - 12);
        } else if (!isAbc(chunk[4]) || !isAbc(chunk[5]) || !isAbc(chunk[6]) ||
                   !isAbc(chunk[7])) {
          break;
        } else {
          if (processing_data(png_ptr, info_ptr, chunk.data(), chunk.size())) {
            break;
          }
          if (!hasInfo) {
            chunksInfo.push_back(chunk);
            continue;
          }
        }
      }
    }

    JXL_RETURN_IF_ERROR(ApplyColorHints(
        color_hints, have_color, ppf->info.num_color_channels == 1, ppf));
  }

  if (errorstate) return false;

  bool has_nontrivial_background = false;
  bool previous_frame_should_be_cleared = false;
  enum {
    DISPOSE_OP_NONE = 0,
    DISPOSE_OP_BACKGROUND = 1,
    DISPOSE_OP_PREVIOUS = 2,
  };
  enum {
    BLEND_OP_SOURCE = 0,
    BLEND_OP_OVER = 1,
  };
  for (size_t i = 0; i < frames.size(); i++) {
    auto& frame = frames[i];
    JXL_ASSERT(frame.data.xsize == frame.xsize);
    JXL_ASSERT(frame.data.ysize == frame.ysize);

    // Before encountering a DISPOSE_OP_NONE frame, the canvas is filled with 0,
    // so DISPOSE_OP_BACKGROUND and DISPOSE_OP_PREVIOUS are equivalent.
    if (frame.dispose_op == DISPOSE_OP_NONE) {
      has_nontrivial_background = true;
    }
    bool should_blend = frame.blend_op == BLEND_OP_OVER;
    bool use_for_next_frame =
        has_nontrivial_background && frame.dispose_op != DISPOSE_OP_PREVIOUS;
    size_t x0 = frame.x0;
    size_t y0 = frame.y0;
    size_t xsize = frame.data.xsize;
    size_t ysize = frame.data.ysize;
    if (previous_frame_should_be_cleared) {
      size_t px0 = frames[i - 1].x0;
      size_t py0 = frames[i - 1].y0;
      size_t pxs = frames[i - 1].xsize;
      size_t pys = frames[i - 1].ysize;
      if (px0 >= x0 && py0 >= y0 && px0 + pxs <= x0 + xsize &&
          py0 + pys <= y0 + ysize && frame.blend_op == BLEND_OP_SOURCE &&
          use_for_next_frame) {
        // If the previous frame is entirely contained in the current frame and
        // we are using BLEND_OP_SOURCE, nothing special needs to be done.
        ppf->frames.emplace_back(std::move(frame.data));
      } else if (px0 == x0 && py0 == y0 && px0 + pxs == x0 + xsize &&
                 py0 + pys == y0 + ysize && use_for_next_frame) {
        // If the new frame has the same size as the old one, but we are
        // blending, we can instead just not blend.
        should_blend = false;
        ppf->frames.emplace_back(std::move(frame.data));
      } else if (px0 <= x0 && py0 <= y0 && px0 + pxs >= x0 + xsize &&
                 py0 + pys >= y0 + ysize && use_for_next_frame) {
        // If the new frame is contained within the old frame, we can pad the
        // new frame with zeros and not blend.
        PackedImage new_data(pxs, pys, frame.data.format);
        memset(new_data.pixels(), 0, new_data.pixels_size);
        for (size_t y = 0; y < ysize; y++) {
          size_t bytes_per_pixel =
              PackedImage::BitsPerChannel(new_data.format.data_type) *
              new_data.format.num_channels / 8;
          memcpy(static_cast<uint8_t*>(new_data.pixels()) +
                     new_data.stride * (y + y0 - py0) +
                     bytes_per_pixel * (x0 - px0),
                 static_cast<const uint8_t*>(frame.data.pixels()) +
                     frame.data.stride * y,
                 xsize * bytes_per_pixel);
        }

        x0 = px0;
        y0 = py0;
        xsize = pxs;
        ysize = pys;
        should_blend = false;
        ppf->frames.emplace_back(std::move(new_data));
      } else {
        // If all else fails, insert a dummy blank frame with kReplace.
        PackedImage blank(pxs, pys, frame.data.format);
        memset(blank.pixels(), 0, blank.pixels_size);
        ppf->frames.emplace_back(std::move(blank));
        auto& pframe = ppf->frames.back();
        pframe.frame_info.layer_info.crop_x0 = px0;
        pframe.frame_info.layer_info.crop_y0 = py0;
        pframe.frame_info.layer_info.xsize = pxs;
        pframe.frame_info.layer_info.ysize = pys;
        pframe.frame_info.duration = 0;
        bool is_full_size = px0 == 0 && py0 == 0 && pxs == ppf->info.xsize &&
                            pys == ppf->info.ysize;
        pframe.frame_info.layer_info.have_crop = is_full_size ? 0 : 1;
        pframe.frame_info.layer_info.blend_info.blendmode = JXL_BLEND_REPLACE;
        pframe.frame_info.layer_info.blend_info.source = 1;
        pframe.frame_info.layer_info.save_as_reference = 1;
        ppf->frames.emplace_back(std::move(frame.data));
      }
    } else {
      ppf->frames.emplace_back(std::move(frame.data));
    }

    auto& pframe = ppf->frames.back();
    pframe.frame_info.layer_info.crop_x0 = x0;
    pframe.frame_info.layer_info.crop_y0 = y0;
    pframe.frame_info.layer_info.xsize = xsize;
    pframe.frame_info.layer_info.ysize = ysize;
    pframe.frame_info.duration = frame.duration;
    pframe.frame_info.layer_info.blend_info.blendmode =
        should_blend ? JXL_BLEND_BLEND : JXL_BLEND_REPLACE;
    bool is_full_size = x0 == 0 && y0 == 0 && xsize == ppf->info.xsize &&
                        ysize == ppf->info.ysize;
    pframe.frame_info.layer_info.have_crop = is_full_size ? 0 : 1;
    pframe.frame_info.layer_info.blend_info.source = 1;
    pframe.frame_info.layer_info.blend_info.alpha = 0;
    pframe.frame_info.layer_info.save_as_reference = use_for_next_frame ? 1 : 0;

    previous_frame_should_be_cleared =
        has_nontrivial_background && frame.dispose_op == DISPOSE_OP_BACKGROUND;
  }
  if (ppf->frames.empty()) return JXL_FAILURE("No frames decoded");
  ppf->frames.back().frame_info.is_last = true;

  return true;
#else
  return false;
#endif
}

}  // namespace extras
}  // namespace jxl
