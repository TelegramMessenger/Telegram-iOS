// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/color_management.h"

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <memory>
#include <string>
#include <utility>

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/color_management.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/dec_tone_mapping-inl.h"
#include "lib/jxl/field_encodings.h"
#include "lib/jxl/matrix_ops.h"
#include "lib/jxl/opsin_params.h"
#include "lib/jxl/transfer_functions-inl.h"

#ifndef JXL_ENABLE_3D_ICC_TONEMAPPING
#define JXL_ENABLE_3D_ICC_TONEMAPPING 1
#endif

HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {

Status ToneMapPixel(const ColorEncoding& c, const float in[3],
                    uint8_t pcslab_out[3]) {
  const PrimariesCIExy primaries = c.GetPrimaries();
  const CIExy white_point = c.GetWhitePoint();
  float primaries_XYZ[9];
  JXL_RETURN_IF_ERROR(PrimariesToXYZ(
      primaries.r.x, primaries.r.y, primaries.g.x, primaries.g.y, primaries.b.x,
      primaries.b.y, white_point.x, white_point.y, primaries_XYZ));
  const float luminances[3] = {primaries_XYZ[3], primaries_XYZ[4],
                               primaries_XYZ[5]};
  float linear[3];
  HWY_CAPPED(float, 1) d;
  if (c.tf.IsPQ()) {
    for (size_t i = 0; i < 3; ++i) {
      linear[i] = TF_PQ().DisplayFromEncoded(in[i]);
    }
  } else {
    for (size_t i = 0; i < 3; ++i) {
      linear[i] = TF_HLG().DisplayFromEncoded(in[i]);
    }
  }
  auto r = LoadU(d, &linear[0]), g = LoadU(d, &linear[1]),
       b = LoadU(d, &linear[2]);
  if (c.tf.IsPQ()) {
    Rec2408ToneMapper<decltype(d)> tone_mapper({0, 10000}, {0, 250},
                                               luminances);
    tone_mapper.ToneMap(&r, &g, &b);
  } else {
    HlgOOTF ootf(/*source_luminance=*/300, /*target_luminance=*/80, luminances);
    ootf.Apply(&r, &g, &b);
  }
  GamutMap(&r, &g, &b, luminances, /*preserve_saturation=*/0.3f);
  StoreU(r, d, &linear[0]);
  StoreU(g, d, &linear[1]);
  StoreU(b, d, &linear[2]);

  float chad[9];
  JXL_RETURN_IF_ERROR(AdaptToXYZD50(white_point.x, white_point.y, chad));
  float to_xyzd50[9];
  Mul3x3Matrix(chad, primaries_XYZ, to_xyzd50);

  float xyz[3] = {0, 0, 0};
  for (size_t xyz_c = 0; xyz_c < 3; ++xyz_c) {
    for (size_t rgb_c = 0; rgb_c < 3; ++rgb_c) {
      xyz[xyz_c] += linear[rgb_c] * to_xyzd50[3 * xyz_c + rgb_c];
    }
  }

  const auto lab_f = [](const float x) {
    static constexpr float kDelta = 6. / 29;
    return x <= kDelta * kDelta * kDelta
               ? x * (1 / (3 * kDelta * kDelta)) + 4.f / 29
               : std::cbrt(x);
  };
  static constexpr float kXn = 0.964212;
  static constexpr float kYn = 1;
  static constexpr float kZn = 0.825188;

  const float f_x = lab_f(xyz[0] / kXn);
  const float f_y = lab_f(xyz[1] / kYn);
  const float f_z = lab_f(xyz[2] / kZn);

  pcslab_out[0] =
      static_cast<uint8_t>(.5f + 255.f * Clamp1(1.16f * f_y - .16f, 0.f, 1.f));
  pcslab_out[1] = static_cast<uint8_t>(
      .5f + 128.f + Clamp1(500 * (f_x - f_y), -128.f, 127.f));
  pcslab_out[2] = static_cast<uint8_t>(
      .5f + 128.f + Clamp1(200 * (f_y - f_z), -128.f, 127.f));

  return true;
}

std::vector<uint16_t> CreateTableCurve(uint32_t N, const ExtraTF tf,
                                       bool tone_map) {
  // The generated PQ curve will make room for highlights up to this luminance.
  // TODO(sboukortt): make this variable?
  static constexpr float kPQIntensityTarget = 10000;

  JXL_ASSERT(N <= 4096);  // ICC MFT2 only allows 4K entries
  JXL_ASSERT(tf == ExtraTF::kPQ || tf == ExtraTF::kHLG);

  static constexpr float kLuminances[] = {1.f / 3, 1.f / 3, 1.f / 3};
  using D = HWY_CAPPED(float, 1);
  Rec2408ToneMapper<D> tone_mapper({0, kPQIntensityTarget},
                                   {0, kDefaultIntensityTarget}, kLuminances);
  // No point using float - LCMS converts to 16-bit for A2B/MFT.
  std::vector<uint16_t> table(N);
  for (uint32_t i = 0; i < N; ++i) {
    const float x = static_cast<float>(i) / (N - 1);  // 1.0 at index N - 1.
    const double dx = static_cast<double>(x);
    // LCMS requires EOTF (e.g. 2.4 exponent).
    double y = (tf == ExtraTF::kHLG) ? TF_HLG().DisplayFromEncoded(dx)
                                     : TF_PQ().DisplayFromEncoded(dx);
    if (tone_map && tf == ExtraTF::kPQ &&
        kPQIntensityTarget > kDefaultIntensityTarget) {
      D df;
      auto r = Set(df, y * 10000 / kPQIntensityTarget), g = r, b = r;
      tone_mapper.ToneMap(&r, &g, &b);
      float fy;
      StoreU(r, df, &fy);
      y = fy;
    }
    JXL_ASSERT(y >= 0.0);
    // Clamp to table range - necessary for HLG.
    if (y > 1.0) y = 1.0;
    // 1.0 corresponds to table value 0xFFFF.
    table[i] = static_cast<uint16_t>(roundf(y * 65535.0));
  }
  return table;
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {

// Local functions.
HWY_EXPORT(ToneMapPixel);
HWY_EXPORT(CreateTableCurve);

Status CIEXYZFromWhiteCIExy(const CIExy& xy, float XYZ[3]) {
  // Target Y = 1.
  if (std::abs(xy.y) < 1e-12) return JXL_FAILURE("Y value is too small");
  const float factor = 1 / xy.y;
  XYZ[0] = xy.x * factor;
  XYZ[1] = 1;
  XYZ[2] = (1 - xy.x - xy.y) * factor;
  return true;
}

namespace {

constexpr bool kEnable3DToneMapping = JXL_ENABLE_3D_ICC_TONEMAPPING;

bool CanToneMap(const ColorEncoding& encoding) {
  // If the color space cannot be represented by a CICP tag in the ICC profile
  // then the rest of the profile must unambiguously identify it; we have less
  // freedom to do use it for tone mapping.
  return encoding.GetColorSpace() == ColorSpace::kRGB &&
         encoding.HasPrimaries() &&
         (encoding.tf.IsPQ() || encoding.tf.IsHLG()) &&
         ((encoding.primaries == Primaries::kP3 &&
           (encoding.white_point == WhitePoint::kD65 ||
            encoding.white_point == WhitePoint::kDCI)) ||
          (encoding.primaries != Primaries::kCustom &&
           encoding.white_point == WhitePoint::kD65));
}

void ICCComputeMD5(const PaddedBytes& data, uint8_t sum[16])
    JXL_NO_SANITIZE("unsigned-integer-overflow") {
  PaddedBytes data64 = data;
  data64.push_back(128);
  // Add bytes such that ((size + 8) & 63) == 0.
  size_t extra = ((64 - ((data64.size() + 8) & 63)) & 63);
  data64.resize(data64.size() + extra, 0);
  for (uint64_t i = 0; i < 64; i += 8) {
    data64.push_back(static_cast<uint64_t>(data.size() << 3u) >> i);
  }

  static const uint32_t sineparts[64] = {
      0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a,
      0xa8304613, 0xfd469501, 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
      0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821, 0xf61e2562, 0xc040b340,
      0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
      0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8,
      0x676f02d9, 0x8d2a4c8a, 0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
      0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70, 0x289b7ec6, 0xeaa127fa,
      0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
      0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92,
      0xffeff47d, 0x85845dd1, 0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
      0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
  };
  static const uint32_t shift[64] = {
      7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
      5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20, 5, 9,  14, 20,
      4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
      6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
  };

  uint32_t a0 = 0x67452301, b0 = 0xefcdab89, c0 = 0x98badcfe, d0 = 0x10325476;

  for (size_t i = 0; i < data64.size(); i += 64) {
    uint32_t a = a0, b = b0, c = c0, d = d0, f, g;
    for (size_t j = 0; j < 64; j++) {
      if (j < 16) {
        f = (b & c) | ((~b) & d);
        g = j;
      } else if (j < 32) {
        f = (d & b) | ((~d) & c);
        g = (5 * j + 1) & 0xf;
      } else if (j < 48) {
        f = b ^ c ^ d;
        g = (3 * j + 5) & 0xf;
      } else {
        f = c ^ (b | (~d));
        g = (7 * j) & 0xf;
      }
      uint32_t dg0 = data64[i + g * 4 + 0], dg1 = data64[i + g * 4 + 1],
               dg2 = data64[i + g * 4 + 2], dg3 = data64[i + g * 4 + 3];
      uint32_t u = dg0 | (dg1 << 8u) | (dg2 << 16u) | (dg3 << 24u);
      f += a + sineparts[j] + u;
      a = d;
      d = c;
      c = b;
      b += (f << shift[j]) | (f >> (32u - shift[j]));
    }
    a0 += a;
    b0 += b;
    c0 += c;
    d0 += d;
  }
  sum[0] = a0;
  sum[1] = a0 >> 8u;
  sum[2] = a0 >> 16u;
  sum[3] = a0 >> 24u;
  sum[4] = b0;
  sum[5] = b0 >> 8u;
  sum[6] = b0 >> 16u;
  sum[7] = b0 >> 24u;
  sum[8] = c0;
  sum[9] = c0 >> 8u;
  sum[10] = c0 >> 16u;
  sum[11] = c0 >> 24u;
  sum[12] = d0;
  sum[13] = d0 >> 8u;
  sum[14] = d0 >> 16u;
  sum[15] = d0 >> 24u;
}

Status CreateICCChadMatrix(CIExy w, float result[9]) {
  float m[9];
  if (w.y == 0) {  // WhitePoint can not be pitch-black.
    return JXL_FAILURE("Invalid WhitePoint");
  }
  JXL_RETURN_IF_ERROR(AdaptToXYZD50(w.x, w.y, m));
  memcpy(result, m, sizeof(float) * 9);
  return true;
}

// Creates RGB to XYZ matrix given RGB primaries and whitepoint in xy.
Status CreateICCRGBMatrix(CIExy r, CIExy g, CIExy b, CIExy w, float result[9]) {
  float m[9];
  JXL_RETURN_IF_ERROR(
      PrimariesToXYZD50(r.x, r.y, g.x, g.y, b.x, b.y, w.x, w.y, m));
  memcpy(result, m, sizeof(float) * 9);
  return true;
}

void WriteICCUint32(uint32_t value, size_t pos, PaddedBytes* JXL_RESTRICT icc) {
  if (icc->size() < pos + 4) icc->resize(pos + 4);
  (*icc)[pos + 0] = (value >> 24u) & 255;
  (*icc)[pos + 1] = (value >> 16u) & 255;
  (*icc)[pos + 2] = (value >> 8u) & 255;
  (*icc)[pos + 3] = value & 255;
}

void WriteICCUint16(uint16_t value, size_t pos, PaddedBytes* JXL_RESTRICT icc) {
  if (icc->size() < pos + 2) icc->resize(pos + 2);
  (*icc)[pos + 0] = (value >> 8u) & 255;
  (*icc)[pos + 1] = value & 255;
}

void WriteICCUint8(uint8_t value, size_t pos, PaddedBytes* JXL_RESTRICT icc) {
  if (icc->size() < pos + 1) icc->resize(pos + 1);
  (*icc)[pos] = value;
}

// Writes a 4-character tag
void WriteICCTag(const char* value, size_t pos, PaddedBytes* JXL_RESTRICT icc) {
  if (icc->size() < pos + 4) icc->resize(pos + 4);
  memcpy(icc->data() + pos, value, 4);
}

Status WriteICCS15Fixed16(float value, size_t pos,
                          PaddedBytes* JXL_RESTRICT icc) {
  // "nextafterf" for 32768.0f towards zero are:
  // 32767.998046875, 32767.99609375, 32767.994140625
  // Even the first value works well,...
  bool ok = (-32767.995f <= value) && (value <= 32767.995f);
  if (!ok) return JXL_FAILURE("ICC value is out of range / NaN");
  int32_t i = value * 65536.0f + 0.5f;
  // Use two's complement
  uint32_t u = static_cast<uint32_t>(i);
  WriteICCUint32(u, pos, icc);
  return true;
}

Status CreateICCHeader(const ColorEncoding& c,
                       PaddedBytes* JXL_RESTRICT header) {
  // TODO(lode): choose color management engine name, e.g. "skia" if
  // integrated in skia.
  static const char* kCmm = "jxl ";

  header->resize(128, 0);

  WriteICCUint32(0, 0, header);  // size, correct value filled in at end
  WriteICCTag(kCmm, 4, header);
  WriteICCUint32(0x04400000u, 8, header);
  const char* profile_type =
      c.GetColorSpace() == ColorSpace::kXYB ? "scnr" : "mntr";
  WriteICCTag(profile_type, 12, header);
  WriteICCTag(c.IsGray() ? "GRAY" : "RGB ", 16, header);
  if (kEnable3DToneMapping && CanToneMap(c)) {
    // We are going to use a 3D LUT for tone mapping, which will be more compact
    // with an 8-bit LUT to CIELAB than with a 16-bit LUT to XYZ. 8-bit XYZ
    // would not be viable due to XYZ being linear, whereas it is fine with
    // CIELAB's ~cube root.
    WriteICCTag("Lab ", 20, header);
  } else {
    WriteICCTag("XYZ ", 20, header);
  }

  // Three uint32_t's date/time encoding.
  // TODO(lode): encode actual date and time, this is a placeholder
  uint32_t year = 2019, month = 12, day = 1;
  uint32_t hour = 0, minute = 0, second = 0;
  WriteICCUint16(year, 24, header);
  WriteICCUint16(month, 26, header);
  WriteICCUint16(day, 28, header);
  WriteICCUint16(hour, 30, header);
  WriteICCUint16(minute, 32, header);
  WriteICCUint16(second, 34, header);

  WriteICCTag("acsp", 36, header);
  WriteICCTag("APPL", 40, header);
  WriteICCUint32(0, 44, header);  // flags
  WriteICCUint32(0, 48, header);  // device manufacturer
  WriteICCUint32(0, 52, header);  // device model
  WriteICCUint32(0, 56, header);  // device attributes
  WriteICCUint32(0, 60, header);  // device attributes
  WriteICCUint32(static_cast<uint32_t>(c.rendering_intent), 64, header);

  // Mandatory D50 white point of profile connection space
  WriteICCUint32(0x0000f6d6, 68, header);
  WriteICCUint32(0x00010000, 72, header);
  WriteICCUint32(0x0000d32d, 76, header);

  WriteICCTag(kCmm, 80, header);

  return true;
}

void AddToICCTagTable(const char* tag, size_t offset, size_t size,
                      PaddedBytes* JXL_RESTRICT tagtable,
                      std::vector<size_t>* offsets) {
  WriteICCTag(tag, tagtable->size(), tagtable);
  // writing true offset deferred to later
  WriteICCUint32(0, tagtable->size(), tagtable);
  offsets->push_back(offset);
  WriteICCUint32(size, tagtable->size(), tagtable);
}

void FinalizeICCTag(PaddedBytes* JXL_RESTRICT tags, size_t* offset,
                    size_t* size) {
  while ((tags->size() & 3) != 0) {
    tags->push_back(0);
  }
  *offset += *size;
  *size = tags->size() - *offset;
}

// The input text must be ASCII, writing other characters to UTF-16 is not
// implemented.
void CreateICCMlucTag(const std::string& text, PaddedBytes* JXL_RESTRICT tags) {
  WriteICCTag("mluc", tags->size(), tags);
  WriteICCUint32(0, tags->size(), tags);
  WriteICCUint32(1, tags->size(), tags);
  WriteICCUint32(12, tags->size(), tags);
  WriteICCTag("enUS", tags->size(), tags);
  WriteICCUint32(text.size() * 2, tags->size(), tags);
  WriteICCUint32(28, tags->size(), tags);
  for (size_t i = 0; i < text.size(); i++) {
    tags->push_back(0);  // prepend 0 for UTF-16
    tags->push_back(text[i]);
  }
}

Status CreateICCXYZTag(float xyz[3], PaddedBytes* JXL_RESTRICT tags) {
  WriteICCTag("XYZ ", tags->size(), tags);
  WriteICCUint32(0, tags->size(), tags);
  for (size_t i = 0; i < 3; ++i) {
    JXL_RETURN_IF_ERROR(WriteICCS15Fixed16(xyz[i], tags->size(), tags));
  }
  return true;
}

Status CreateICCChadTag(float chad[9], PaddedBytes* JXL_RESTRICT tags) {
  WriteICCTag("sf32", tags->size(), tags);
  WriteICCUint32(0, tags->size(), tags);
  for (size_t i = 0; i < 9; i++) {
    JXL_RETURN_IF_ERROR(WriteICCS15Fixed16(chad[i], tags->size(), tags));
  }
  return true;
}

void MaybeCreateICCCICPTag(const ColorEncoding& c,
                           PaddedBytes* JXL_RESTRICT tags, size_t* offset,
                           size_t* size, PaddedBytes* JXL_RESTRICT tagtable,
                           std::vector<size_t>* offsets) {
  if (c.GetColorSpace() != ColorSpace::kRGB) {
    return;
  }
  uint8_t primaries = 0;
  if (c.primaries == Primaries::kP3) {
    if (c.white_point == WhitePoint::kD65) {
      primaries = 12;
    } else if (c.white_point == WhitePoint::kDCI) {
      primaries = 11;
    } else {
      return;
    }
  } else if (c.primaries != Primaries::kCustom &&
             c.white_point == WhitePoint::kD65) {
    primaries = static_cast<uint8_t>(c.primaries);
  } else {
    return;
  }
  if (c.tf.IsUnknown() || c.tf.IsGamma()) {
    return;
  }
  WriteICCTag("cicp", tags->size(), tags);
  WriteICCUint32(0, tags->size(), tags);
  WriteICCUint8(primaries, tags->size(), tags);
  WriteICCUint8(static_cast<uint8_t>(c.tf.GetTransferFunction()), tags->size(),
                tags);
  // Matrix
  WriteICCUint8(0, tags->size(), tags);
  // Full range
  WriteICCUint8(1, tags->size(), tags);
  FinalizeICCTag(tags, offset, size);
  AddToICCTagTable("cicp", *offset, *size, tagtable, offsets);
}

void CreateICCCurvCurvTag(const std::vector<uint16_t>& curve,
                          PaddedBytes* JXL_RESTRICT tags) {
  size_t pos = tags->size();
  tags->resize(tags->size() + 12 + curve.size() * 2, 0);
  WriteICCTag("curv", pos, tags);
  WriteICCUint32(0, pos + 4, tags);
  WriteICCUint32(curve.size(), pos + 8, tags);
  for (size_t i = 0; i < curve.size(); i++) {
    WriteICCUint16(curve[i], pos + 12 + i * 2, tags);
  }
}

// Writes 12 + 4*params.size() bytes
Status CreateICCCurvParaTag(std::vector<float> params, size_t curve_type,
                            PaddedBytes* JXL_RESTRICT tags) {
  WriteICCTag("para", tags->size(), tags);
  WriteICCUint32(0, tags->size(), tags);
  WriteICCUint16(curve_type, tags->size(), tags);
  WriteICCUint16(0, tags->size(), tags);
  for (size_t i = 0; i < params.size(); i++) {
    JXL_RETURN_IF_ERROR(WriteICCS15Fixed16(params[i], tags->size(), tags));
  }
  return true;
}

Status CreateICCLutAtoBTagForXYB(PaddedBytes* JXL_RESTRICT tags) {
  WriteICCTag("mAB ", tags->size(), tags);
  // 4 reserved bytes set to 0
  WriteICCUint32(0, tags->size(), tags);
  // number of input channels
  WriteICCUint8(3, tags->size(), tags);
  // number of output channels
  WriteICCUint8(3, tags->size(), tags);
  // 2 reserved bytes for padding
  WriteICCUint16(0, tags->size(), tags);
  // offset to first B curve
  WriteICCUint32(32, tags->size(), tags);
  // offset to matrix
  WriteICCUint32(244, tags->size(), tags);
  // offset to first M curve
  WriteICCUint32(148, tags->size(), tags);
  // offset to CLUT
  WriteICCUint32(80, tags->size(), tags);
  // offset to first A curve
  // (reuse linear B curves)
  WriteICCUint32(32, tags->size(), tags);

  // offset = 32
  // no-op curves
  JXL_RETURN_IF_ERROR(CreateICCCurvParaTag({1.0f}, 0, tags));
  JXL_RETURN_IF_ERROR(CreateICCCurvParaTag({1.0f}, 0, tags));
  JXL_RETURN_IF_ERROR(CreateICCCurvParaTag({1.0f}, 0, tags));
  // offset = 80
  // number of grid points for each input channel
  for (int i = 0; i < 16; ++i) {
    WriteICCUint8(i < 3 ? 2 : 0, tags->size(), tags);
  }
  // precision = 2
  WriteICCUint8(2, tags->size(), tags);
  // 3 bytes of padding
  WriteICCUint8(0, tags->size(), tags);
  WriteICCUint16(0, tags->size(), tags);
  const float kOffsets[3] = {
      kScaledXYBOffset[0] + kScaledXYBOffset[1],
      kScaledXYBOffset[1] - kScaledXYBOffset[0] + 1.0f / kScaledXYBScale[0],
      kScaledXYBOffset[1] + kScaledXYBOffset[2]};
  const float kScaling[3] = {
      1.0f / (1.0f / kScaledXYBScale[0] + 1.0f / kScaledXYBScale[1]),
      1.0f / (1.0f / kScaledXYBScale[0] + 1.0f / kScaledXYBScale[1]),
      1.0f / (1.0f / kScaledXYBScale[1] + 1.0f / kScaledXYBScale[2])};
  // 2*2*2*3 entries of 2 bytes each = 48 bytes
  for (size_t ix = 0; ix < 2; ++ix) {
    for (size_t iy = 0; iy < 2; ++iy) {
      for (size_t ib = 0; ib < 2; ++ib) {
        float in_f[3] = {ix * 1.0f, iy * 1.0f, ib * 1.0f};
        for (size_t c = 0; c < 3; ++c) {
          in_f[c] /= kScaledXYBScale[c];
          in_f[c] -= kScaledXYBOffset[c];
        }
        float out_f[3];
        out_f[0] = in_f[1] + in_f[0];
        out_f[1] = in_f[1] - in_f[0];
        out_f[2] = in_f[2] + in_f[1];
        for (int i = 0; i < 3; ++i) {
          out_f[i] += kOffsets[i];
          out_f[i] *= kScaling[i];
        }
        for (int i = 0; i < 3; ++i) {
          JXL_RETURN_IF_ERROR(out_f[i] >= 0.f && out_f[i] <= 1.f);
          uint16_t val = static_cast<uint16_t>(
              0.5f + 65535 * std::max(0.f, std::min(1.f, out_f[i])));
          WriteICCUint16(val, tags->size(), tags);
        }
      }
    }
  }
  // offset = 148
  // 3 curves with 5 parameters = 3 * (12 + 5 * 4) = 96 bytes
  for (size_t i = 0; i < 3; ++i) {
    const float b =
        -kOffsets[i] - std::cbrt(jxl::kNegOpsinAbsorbanceBiasRGB[i]);
    std::vector<float> params = {
        3,
        1.0f / kScaling[i],
        b,
        0,                                // unused
        std::max(0.f, -b * kScaling[i]),  // make skcms happy
    };
    JXL_RETURN_IF_ERROR(CreateICCCurvParaTag(params, 3, tags));
  }
  // offset = 244
  const double matrix[] = {1.5170095, -1.1065225, 0.071623,
                           -0.050022, 0.5683655,  -0.018344,
                           -1.387676, 1.1145555,  0.6857255};
  // 12 * 4 = 48 bytes
  for (size_t i = 0; i < 9; ++i) {
    JXL_RETURN_IF_ERROR(WriteICCS15Fixed16(matrix[i], tags->size(), tags));
  }
  for (size_t i = 0; i < 3; ++i) {
    float intercept = 0;
    for (size_t j = 0; j < 3; ++j) {
      intercept += matrix[i * 3 + j] * jxl::kNegOpsinAbsorbanceBiasRGB[j];
    }
    JXL_RETURN_IF_ERROR(WriteICCS15Fixed16(intercept, tags->size(), tags));
  }
  return true;
}

Status CreateICCLutAtoBTagForHDR(ColorEncoding c,
                                 PaddedBytes* JXL_RESTRICT tags) {
  static constexpr size_t k3DLutDim = 9;
  WriteICCTag("mft1", tags->size(), tags);
  // 4 reserved bytes set to 0
  WriteICCUint32(0, tags->size(), tags);
  // number of input channels
  WriteICCUint8(3, tags->size(), tags);
  // number of output channels
  WriteICCUint8(3, tags->size(), tags);
  // number of CLUT grid points
  WriteICCUint8(k3DLutDim, tags->size(), tags);
  // 1 reserved bytes for padding
  WriteICCUint8(0, tags->size(), tags);

  // Matrix (per specification, must be identity if input is not XYZ)
  for (size_t i = 0; i < 3; ++i) {
    for (size_t j = 0; j < 3; ++j) {
      JXL_RETURN_IF_ERROR(
          WriteICCS15Fixed16(i == j ? 1.f : 0.f, tags->size(), tags));
    }
  }

  // Input tables
  for (size_t c = 0; c < 3; ++c) {
    for (size_t i = 0; i < 256; ++i) {
      WriteICCUint8(i, tags->size(), tags);
    }
  }

  for (size_t ix = 0; ix < k3DLutDim; ++ix) {
    for (size_t iy = 0; iy < k3DLutDim; ++iy) {
      for (size_t ib = 0; ib < k3DLutDim; ++ib) {
        float f[3] = {ix * (1.0f / (k3DLutDim - 1)),
                      iy * (1.0f / (k3DLutDim - 1)),
                      ib * (1.0f / (k3DLutDim - 1))};
        uint8_t pcslab_out[3];
        JXL_RETURN_IF_ERROR(
            HWY_DYNAMIC_DISPATCH(ToneMapPixel)(c, f, pcslab_out));
        for (uint8_t val : pcslab_out) {
          WriteICCUint8(val, tags->size(), tags);
        }
      }
    }
  }

  // Output tables
  for (size_t c = 0; c < 3; ++c) {
    for (size_t i = 0; i < 256; ++i) {
      WriteICCUint8(i, tags->size(), tags);
    }
  }

  return true;
}

// Some software (Apple Safari, Preview) requires this.
Status CreateICCNoOpBToATag(PaddedBytes* JXL_RESTRICT tags) {
  WriteICCTag("mBA ", tags->size(), tags);
  // 4 reserved bytes set to 0
  WriteICCUint32(0, tags->size(), tags);
  // number of input channels
  WriteICCUint8(3, tags->size(), tags);
  // number of output channels
  WriteICCUint8(3, tags->size(), tags);
  // 2 reserved bytes for padding
  WriteICCUint16(0, tags->size(), tags);
  // offset to first B curve
  WriteICCUint32(32, tags->size(), tags);
  // offset to matrix
  WriteICCUint32(0, tags->size(), tags);
  // offset to first M curve
  WriteICCUint32(0, tags->size(), tags);
  // offset to CLUT
  WriteICCUint32(0, tags->size(), tags);
  // offset to first A curve
  WriteICCUint32(0, tags->size(), tags);

  JXL_RETURN_IF_ERROR(CreateICCCurvParaTag({1.0f}, 0, tags));
  JXL_RETURN_IF_ERROR(CreateICCCurvParaTag({1.0f}, 0, tags));
  JXL_RETURN_IF_ERROR(CreateICCCurvParaTag({1.0f}, 0, tags));

  return true;
}

}  // namespace

Status MaybeCreateProfile(const ColorEncoding& c,
                          PaddedBytes* JXL_RESTRICT icc) {
  PaddedBytes header, tagtable, tags;

  if (c.GetColorSpace() == ColorSpace::kUnknown || c.tf.IsUnknown()) {
    return false;  // Not an error
  }

  switch (c.GetColorSpace()) {
    case ColorSpace::kRGB:
    case ColorSpace::kGray:
    case ColorSpace::kXYB:
      break;  // OK
    default:
      return JXL_FAILURE("Invalid CS %u",
                         static_cast<unsigned int>(c.GetColorSpace()));
  }

  if (c.GetColorSpace() == ColorSpace::kXYB &&
      c.rendering_intent != RenderingIntent::kPerceptual) {
    return JXL_FAILURE(
        "Only perceptual rendering intent implemented for XYB "
        "ICC profile.");
  }

  JXL_RETURN_IF_ERROR(CreateICCHeader(c, &header));

  std::vector<size_t> offsets;
  // tag count, deferred to later
  WriteICCUint32(0, tagtable.size(), &tagtable);

  size_t tag_offset = 0, tag_size = 0;

  CreateICCMlucTag(Description(c), &tags);
  FinalizeICCTag(&tags, &tag_offset, &tag_size);
  AddToICCTagTable("desc", tag_offset, tag_size, &tagtable, &offsets);

  const std::string copyright = "CC0";
  CreateICCMlucTag(copyright, &tags);
  FinalizeICCTag(&tags, &tag_offset, &tag_size);
  AddToICCTagTable("cprt", tag_offset, tag_size, &tagtable, &offsets);

  // TODO(eustas): isn't it the other way round: gray image has d50 WhitePoint?
  if (c.IsGray()) {
    float wtpt[3];
    JXL_RETURN_IF_ERROR(CIEXYZFromWhiteCIExy(c.GetWhitePoint(), wtpt));
    JXL_RETURN_IF_ERROR(CreateICCXYZTag(wtpt, &tags));
  } else {
    float d50[3] = {0.964203, 1.0, 0.824905};
    JXL_RETURN_IF_ERROR(CreateICCXYZTag(d50, &tags));
  }
  FinalizeICCTag(&tags, &tag_offset, &tag_size);
  AddToICCTagTable("wtpt", tag_offset, tag_size, &tagtable, &offsets);

  if (!c.IsGray()) {
    // Chromatic adaptation matrix
    float chad[9];
    JXL_RETURN_IF_ERROR(CreateICCChadMatrix(c.GetWhitePoint(), chad));

    JXL_RETURN_IF_ERROR(CreateICCChadTag(chad, &tags));
    FinalizeICCTag(&tags, &tag_offset, &tag_size);
    AddToICCTagTable("chad", tag_offset, tag_size, &tagtable, &offsets);
  }

  if (c.GetColorSpace() == ColorSpace::kRGB) {
    MaybeCreateICCCICPTag(c, &tags, &tag_offset, &tag_size, &tagtable,
                          &offsets);

    const PrimariesCIExy primaries = c.GetPrimaries();
    float m[9];
    JXL_RETURN_IF_ERROR(CreateICCRGBMatrix(primaries.r, primaries.g,
                                           primaries.b, c.GetWhitePoint(), m));
    float r[3] = {m[0], m[3], m[6]};
    float g[3] = {m[1], m[4], m[7]};
    float b[3] = {m[2], m[5], m[8]};

    JXL_RETURN_IF_ERROR(CreateICCXYZTag(r, &tags));
    FinalizeICCTag(&tags, &tag_offset, &tag_size);
    AddToICCTagTable("rXYZ", tag_offset, tag_size, &tagtable, &offsets);

    JXL_RETURN_IF_ERROR(CreateICCXYZTag(g, &tags));
    FinalizeICCTag(&tags, &tag_offset, &tag_size);
    AddToICCTagTable("gXYZ", tag_offset, tag_size, &tagtable, &offsets);

    JXL_RETURN_IF_ERROR(CreateICCXYZTag(b, &tags));
    FinalizeICCTag(&tags, &tag_offset, &tag_size);
    AddToICCTagTable("bXYZ", tag_offset, tag_size, &tagtable, &offsets);
  }

  if (c.GetColorSpace() == ColorSpace::kXYB) {
    JXL_RETURN_IF_ERROR(CreateICCLutAtoBTagForXYB(&tags));
    FinalizeICCTag(&tags, &tag_offset, &tag_size);
    AddToICCTagTable("A2B0", tag_offset, tag_size, &tagtable, &offsets);
    JXL_RETURN_IF_ERROR(CreateICCNoOpBToATag(&tags));
    FinalizeICCTag(&tags, &tag_offset, &tag_size);
    AddToICCTagTable("B2A0", tag_offset, tag_size, &tagtable, &offsets);
  } else if (kEnable3DToneMapping && CanToneMap(c)) {
    JXL_RETURN_IF_ERROR(CreateICCLutAtoBTagForHDR(c, &tags));
    FinalizeICCTag(&tags, &tag_offset, &tag_size);
    AddToICCTagTable("A2B0", tag_offset, tag_size, &tagtable, &offsets);
    JXL_RETURN_IF_ERROR(CreateICCNoOpBToATag(&tags));
    FinalizeICCTag(&tags, &tag_offset, &tag_size);
    AddToICCTagTable("B2A0", tag_offset, tag_size, &tagtable, &offsets);
  } else {
    if (c.tf.IsGamma()) {
      float gamma = 1.0 / c.tf.GetGamma();
      JXL_RETURN_IF_ERROR(CreateICCCurvParaTag({gamma}, 0, &tags));
    } else if (c.GetColorSpace() != ColorSpace::kXYB) {
      switch (c.tf.GetTransferFunction()) {
        case TransferFunction::kHLG:
          CreateICCCurvCurvTag(HWY_DYNAMIC_DISPATCH(CreateTableCurve)(
                                   64, ExtraTF::kHLG, CanToneMap(c)),
                               &tags);
          break;
        case TransferFunction::kPQ:
          CreateICCCurvCurvTag(HWY_DYNAMIC_DISPATCH(CreateTableCurve)(
                                   64, ExtraTF::kPQ, CanToneMap(c)),
                               &tags);
          break;
        case TransferFunction::kSRGB:
          JXL_RETURN_IF_ERROR(CreateICCCurvParaTag(
              {2.4, 1.0 / 1.055, 0.055 / 1.055, 1.0 / 12.92, 0.04045}, 3,
              &tags));
          break;
        case TransferFunction::k709:
          JXL_RETURN_IF_ERROR(CreateICCCurvParaTag(
              {1.0 / 0.45, 1.0 / 1.099, 0.099 / 1.099, 1.0 / 4.5, 0.081}, 3,
              &tags));
          break;
        case TransferFunction::kLinear:
          JXL_RETURN_IF_ERROR(
              CreateICCCurvParaTag({1.0, 1.0, 0.0, 1.0, 0.0}, 3, &tags));
          break;
        case TransferFunction::kDCI:
          JXL_RETURN_IF_ERROR(
              CreateICCCurvParaTag({2.6, 1.0, 0.0, 1.0, 0.0}, 3, &tags));
          break;
        default:
          JXL_UNREACHABLE("Unknown TF %u", static_cast<unsigned int>(
                                               c.tf.GetTransferFunction()));
      }
    }
    FinalizeICCTag(&tags, &tag_offset, &tag_size);
    if (c.IsGray()) {
      AddToICCTagTable("kTRC", tag_offset, tag_size, &tagtable, &offsets);
    } else {
      AddToICCTagTable("rTRC", tag_offset, tag_size, &tagtable, &offsets);
      AddToICCTagTable("gTRC", tag_offset, tag_size, &tagtable, &offsets);
      AddToICCTagTable("bTRC", tag_offset, tag_size, &tagtable, &offsets);
    }
  }

  // Tag count
  WriteICCUint32(offsets.size(), 0, &tagtable);
  for (size_t i = 0; i < offsets.size(); i++) {
    WriteICCUint32(offsets[i] + header.size() + tagtable.size(), 4 + 12 * i + 4,
                   &tagtable);
  }

  // ICC profile size
  WriteICCUint32(header.size() + tagtable.size() + tags.size(), 0, &header);

  *icc = header;
  icc->append(tagtable);
  icc->append(tags);

  // The MD5 checksum must be computed on the profile with profile flags,
  // rendering intent, and region of the checksum itself, set to 0.
  // TODO(lode): manually verify with a reliable tool that this creates correct
  // signature (profile id) for ICC profiles.
  PaddedBytes icc_sum = *icc;
  if (icc_sum.size() >= 64 + 4) {
    memset(icc_sum.data() + 44, 0, 4);
    memset(icc_sum.data() + 64, 0, 4);
  }
  uint8_t checksum[16];
  ICCComputeMD5(icc_sum, checksum);

  memcpy(icc->data() + 84, checksum, sizeof(checksum));

  return true;
}

}  // namespace jxl
#endif  // HWY_ONCE
