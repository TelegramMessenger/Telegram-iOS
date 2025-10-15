// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_COMMON_H_
#define LIB_JXL_COMMON_H_

// Shared constants and helper functions.

#include <inttypes.h>
#include <stddef.h>
#include <stdio.h>

#include <limits>  // numeric_limits
#include <memory>  // unique_ptr
#include <string>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/padded_bytes.h"

#ifndef JXL_HIGH_PRECISION
#define JXL_HIGH_PRECISION 1
#endif

// Macro that defines whether support for decoding JXL files to JPEG is enabled.
#ifndef JPEGXL_ENABLE_TRANSCODE_JPEG
#define JPEGXL_ENABLE_TRANSCODE_JPEG 1
#endif  // JPEGXL_ENABLE_TRANSCODE_JPEG

// Macro that defines whether support for decoding boxes is enabled.
#ifndef JPEGXL_ENABLE_BOXES
#define JPEGXL_ENABLE_BOXES 1
#endif  // JPEGXL_ENABLE_BOXES

namespace jxl {
// Some enums and typedefs used by more than one header file.

constexpr size_t kBitsPerByte = 8;  // more clear than CHAR_BIT

constexpr inline size_t RoundUpBitsToByteMultiple(size_t bits) {
  return (bits + 7) & ~size_t(7);
}

constexpr inline size_t RoundUpToBlockDim(size_t dim) {
  return (dim + 7) & ~size_t(7);
}

static inline bool JXL_MAYBE_UNUSED SafeAdd(const uint64_t a, const uint64_t b,
                                            uint64_t& sum) {
  sum = a + b;
  return sum >= a;  // no need to check b - either sum >= both or < both.
}

template <typename T1, typename T2>
constexpr inline T1 DivCeil(T1 a, T2 b) {
  return (a + b - 1) / b;
}

// Works for any `align`; if a power of two, compiler emits ADD+AND.
constexpr inline size_t RoundUpTo(size_t what, size_t align) {
  return DivCeil(what, align) * align;
}

constexpr double kPi = 3.14159265358979323846264338327950288;

// Reasonable default for sRGB, matches common monitors. We map white to this
// many nits (cd/m^2) by default. Butteraugli was tuned for 250 nits, which is
// very close.
static constexpr float kDefaultIntensityTarget = 255;

template <typename T>
constexpr T Pi(T multiplier) {
  return static_cast<T>(multiplier * kPi);
}

// Block is the square grid of pixels to which an "energy compaction"
// transformation (e.g. DCT) is applied. Each block has its own AC quantizer.
constexpr size_t kBlockDim = 8;

constexpr size_t kDCTBlockSize = kBlockDim * kBlockDim;

constexpr size_t kGroupDim = 256;
static_assert(kGroupDim % kBlockDim == 0,
              "Group dim should be divisible by block dim");
constexpr size_t kGroupDimInBlocks = kGroupDim / kBlockDim;

// Maximum number of passes in an image.
constexpr size_t kMaxNumPasses = 11;

// Maximum number of reference frames.
constexpr size_t kMaxNumReferenceFrames = 4;

// Dimensions of a frame, in pixels, and other derived dimensions.
// Computed from FrameHeader.
// TODO(veluca): add extra channels.
struct FrameDimensions {
  void Set(size_t xsize, size_t ysize, size_t group_size_shift,
           size_t max_hshift, size_t max_vshift, bool modular_mode,
           size_t upsampling) {
    group_dim = (kGroupDim >> 1) << group_size_shift;
    dc_group_dim = group_dim * kBlockDim;
    xsize_upsampled = xsize;
    ysize_upsampled = ysize;
    this->xsize = DivCeil(xsize, upsampling);
    this->ysize = DivCeil(ysize, upsampling);
    xsize_blocks = DivCeil(this->xsize, kBlockDim << max_hshift) << max_hshift;
    ysize_blocks = DivCeil(this->ysize, kBlockDim << max_vshift) << max_vshift;
    xsize_padded = xsize_blocks * kBlockDim;
    ysize_padded = ysize_blocks * kBlockDim;
    if (modular_mode) {
      // Modular mode doesn't have any padding.
      xsize_padded = this->xsize;
      ysize_padded = this->ysize;
    }
    xsize_upsampled_padded = xsize_padded * upsampling;
    ysize_upsampled_padded = ysize_padded * upsampling;
    xsize_groups = DivCeil(this->xsize, group_dim);
    ysize_groups = DivCeil(this->ysize, group_dim);
    xsize_dc_groups = DivCeil(xsize_blocks, group_dim);
    ysize_dc_groups = DivCeil(ysize_blocks, group_dim);
    num_groups = xsize_groups * ysize_groups;
    num_dc_groups = xsize_dc_groups * ysize_dc_groups;
  }

  // Image size without any upsampling, i.e. original_size / upsampling.
  size_t xsize;
  size_t ysize;
  // Original image size.
  size_t xsize_upsampled;
  size_t ysize_upsampled;
  // Image size after upsampling the padded image.
  size_t xsize_upsampled_padded;
  size_t ysize_upsampled_padded;
  // Image size after padding to a multiple of kBlockDim (if VarDCT mode).
  size_t xsize_padded;
  size_t ysize_padded;
  // Image size in kBlockDim blocks.
  size_t xsize_blocks;
  size_t ysize_blocks;
  // Image size in number of groups.
  size_t xsize_groups;
  size_t ysize_groups;
  // Image size in number of DC groups.
  size_t xsize_dc_groups;
  size_t ysize_dc_groups;
  // Number of AC or DC groups.
  size_t num_groups;
  size_t num_dc_groups;
  // Size of a group.
  size_t group_dim;
  size_t dc_group_dim;
};

// Prior to C++14 (i.e. C++11): provide our own make_unique
#if __cplusplus < 201402L
template <typename T, typename... Args>
std::unique_ptr<T> make_unique(Args&&... args) {
  return std::unique_ptr<T>(new T(std::forward<Args>(args)...));
}
#else
using std::make_unique;
#endif

template <typename T>
JXL_INLINE T Clamp1(T val, T low, T hi) {
  return val < low ? low : val > hi ? hi : val;
}

// Encodes non-negative (X) into (2 * X), negative (-X) into (2 * X - 1)
constexpr uint32_t PackSigned(int32_t value)
    JXL_NO_SANITIZE("unsigned-integer-overflow") {
  return (static_cast<uint32_t>(value) << 1) ^
         ((static_cast<uint32_t>(~value) >> 31) - 1);
}

// Reverse to PackSigned, i.e. UnpackSigned(PackSigned(X)) == X.
// (((~value) & 1) - 1) is either 0 or 0xFF...FF and it will have an expected
// unsigned-integer-overflow.
constexpr intptr_t UnpackSigned(size_t value)
    JXL_NO_SANITIZE("unsigned-integer-overflow") {
  return static_cast<intptr_t>((value >> 1) ^ (((~value) & 1) - 1));
}

// conversion from integer to string.
template <typename T>
std::string ToString(T n) {
  char data[32] = {};
  if (T(0.1) != T(0)) {
    // float
    snprintf(data, sizeof(data), "%g", static_cast<double>(n));
  } else if (T(-1) > T(0)) {
    // unsigned
    snprintf(data, sizeof(data), "%llu", static_cast<unsigned long long>(n));
  } else {
    // signed
    snprintf(data, sizeof(data), "%lld", static_cast<long long>(n));
  }
  return data;
}

static inline JXL_MAYBE_UNUSED uint64_t DecodeVarInt(const uint8_t* input,
                                                     size_t inputSize,
                                                     size_t* pos) {
  size_t i;
  uint64_t ret = 0;
  for (i = 0; *pos + i < inputSize && i < 10; ++i) {
    ret |= uint64_t(input[*pos + i] & 127) << uint64_t(7 * i);
    // If the next-byte flag is not set, stop
    if ((input[*pos + i] & 128) == 0) break;
  }
  // TODO: Return a decoding error if i == 10.
  *pos += i + 1;
  return ret;
}

static inline JXL_MAYBE_UNUSED bool EncodeVarInt(uint64_t value,
                                                 size_t output_size,
                                                 size_t* output_pos,
                                                 uint8_t* output) {
  // While more than 7 bits of data are left,
  // store 7 bits and set the next byte flag
  while (value > 127) {
    if (*output_pos > output_size) return false;
    // |128: Set the next byte flag
    output[(*output_pos)++] = ((uint8_t)(value & 127)) | 128;
    // Remove the seven bits we just wrote
    value >>= 7;
  }
  if (*output_pos > output_size) return false;
  output[(*output_pos)++] = ((uint8_t)value) & 127;
  return true;
}

static inline JXL_MAYBE_UNUSED void EncodeVarInt(uint64_t value,
                                                 PaddedBytes* data) {
  size_t pos = data->size();
  data->resize(data->size() + 9);
  JXL_CHECK(EncodeVarInt(value, data->size(), &pos, data->data()));
  data->resize(pos);
}

}  // namespace jxl

#endif  // LIB_JXL_COMMON_H_
