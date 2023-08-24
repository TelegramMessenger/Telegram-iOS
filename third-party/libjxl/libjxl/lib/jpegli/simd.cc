// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/simd.h"

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jpegli/simd.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

HWY_BEFORE_NAMESPACE();
namespace jpegli {
namespace HWY_NAMESPACE {

size_t GetVectorSize() { return HWY_LANES(uint8_t); }

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jpegli
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jpegli {
namespace {

HWY_EXPORT(GetVectorSize);  // Local function.

}  // namespace

size_t VectorSize() {
  static size_t bytes = HWY_DYNAMIC_DISPATCH(GetVectorSize)();
  return bytes;
}

}  // namespace jpegli
#endif  // HWY_ONCE
