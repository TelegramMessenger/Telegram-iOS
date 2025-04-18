// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_SIZE_CONSTRAINTS_H_
#define LIB_JXL_SIZE_CONSTRAINTS_H_

#include <cstdint>
#include <type_traits>

#include "lib/jxl/base/status.h"

namespace jxl {

struct SizeConstraints {
  // Upper limit on pixel dimensions/area, enforced by VerifyDimensions
  // (called from decoders). Fuzzers set smaller values to limit memory use.
  uint32_t dec_max_xsize = 0xFFFFFFFFu;
  uint32_t dec_max_ysize = 0xFFFFFFFFu;
  uint64_t dec_max_pixels = 0xFFFFFFFFu;  // Might be up to ~0ull
};

template <typename T,
          class = typename std::enable_if<std::is_unsigned<T>::value>::type>
Status VerifyDimensions(const SizeConstraints* constraints, T xs, T ys) {
  if (!constraints) return true;

  if (xs == 0 || ys == 0) return JXL_FAILURE("Empty image.");
  if (xs > constraints->dec_max_xsize) return JXL_FAILURE("Image too wide.");
  if (ys > constraints->dec_max_ysize) return JXL_FAILURE("Image too tall.");

  const uint64_t num_pixels = static_cast<uint64_t>(xs) * ys;
  if (num_pixels > constraints->dec_max_pixels) {
    return JXL_FAILURE("Image too big.");
  }

  return true;
}

}  // namespace jxl

#endif  // LIB_JXL_SIZE_CONSTRAINTS_H_
