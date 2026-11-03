// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#if defined(LIB_JPEGLI_TRANSPOSE_INL_H_) == defined(HWY_TARGET_TOGGLE)
#ifdef LIB_JPEGLI_TRANSPOSE_INL_H_
#undef LIB_JPEGLI_TRANSPOSE_INL_H_
#else
#define LIB_JPEGLI_TRANSPOSE_INL_H_
#endif

#include "lib/jxl/base/compiler_specific.h"

HWY_BEFORE_NAMESPACE();
namespace jpegli {
namespace HWY_NAMESPACE {
namespace {

#if HWY_CAP_GE256
static JXL_INLINE void Transpose8x8Block(const float* JXL_RESTRICT from,
                                         float* JXL_RESTRICT to) {
  const HWY_CAPPED(float, 8) d;
  auto i0 = Load(d, from);
  auto i1 = Load(d, from + 1 * 8);
  auto i2 = Load(d, from + 2 * 8);
  auto i3 = Load(d, from + 3 * 8);
  auto i4 = Load(d, from + 4 * 8);
  auto i5 = Load(d, from + 5 * 8);
  auto i6 = Load(d, from + 6 * 8);
  auto i7 = Load(d, from + 7 * 8);

  const auto q0 = InterleaveLower(d, i0, i2);
  const auto q1 = InterleaveLower(d, i1, i3);
  const auto q2 = InterleaveUpper(d, i0, i2);
  const auto q3 = InterleaveUpper(d, i1, i3);
  const auto q4 = InterleaveLower(d, i4, i6);
  const auto q5 = InterleaveLower(d, i5, i7);
  const auto q6 = InterleaveUpper(d, i4, i6);
  const auto q7 = InterleaveUpper(d, i5, i7);

  const auto r0 = InterleaveLower(d, q0, q1);
  const auto r1 = InterleaveUpper(d, q0, q1);
  const auto r2 = InterleaveLower(d, q2, q3);
  const auto r3 = InterleaveUpper(d, q2, q3);
  const auto r4 = InterleaveLower(d, q4, q5);
  const auto r5 = InterleaveUpper(d, q4, q5);
  const auto r6 = InterleaveLower(d, q6, q7);
  const auto r7 = InterleaveUpper(d, q6, q7);

  i0 = ConcatLowerLower(d, r4, r0);
  i1 = ConcatLowerLower(d, r5, r1);
  i2 = ConcatLowerLower(d, r6, r2);
  i3 = ConcatLowerLower(d, r7, r3);
  i4 = ConcatUpperUpper(d, r4, r0);
  i5 = ConcatUpperUpper(d, r5, r1);
  i6 = ConcatUpperUpper(d, r6, r2);
  i7 = ConcatUpperUpper(d, r7, r3);

  Store(i0, d, to);
  Store(i1, d, to + 1 * 8);
  Store(i2, d, to + 2 * 8);
  Store(i3, d, to + 3 * 8);
  Store(i4, d, to + 4 * 8);
  Store(i5, d, to + 5 * 8);
  Store(i6, d, to + 6 * 8);
  Store(i7, d, to + 7 * 8);
}
#elif HWY_TARGET != HWY_SCALAR
static JXL_INLINE void Transpose8x8Block(const float* JXL_RESTRICT from,
                                         float* JXL_RESTRICT to) {
  const HWY_CAPPED(float, 4) d;
  for (size_t n = 0; n < 8; n += 4) {
    for (size_t m = 0; m < 8; m += 4) {
      auto p0 = Load(d, from + n * 8 + m);
      auto p1 = Load(d, from + (n + 1) * 8 + m);
      auto p2 = Load(d, from + (n + 2) * 8 + m);
      auto p3 = Load(d, from + (n + 3) * 8 + m);
      const auto q0 = InterleaveLower(d, p0, p2);
      const auto q1 = InterleaveLower(d, p1, p3);
      const auto q2 = InterleaveUpper(d, p0, p2);
      const auto q3 = InterleaveUpper(d, p1, p3);

      const auto r0 = InterleaveLower(d, q0, q1);
      const auto r1 = InterleaveUpper(d, q0, q1);
      const auto r2 = InterleaveLower(d, q2, q3);
      const auto r3 = InterleaveUpper(d, q2, q3);
      Store(r0, d, to + m * 8 + n);
      Store(r1, d, to + (1 + m) * 8 + n);
      Store(r2, d, to + (2 + m) * 8 + n);
      Store(r3, d, to + (3 + m) * 8 + n);
    }
  }
}
#else
static JXL_INLINE void Transpose8x8Block(const float* JXL_RESTRICT from,
                                         float* JXL_RESTRICT to) {
  for (size_t n = 0; n < 8; ++n) {
    for (size_t m = 0; m < 8; ++m) {
      to[8 * n + m] = from[8 * m + n];
    }
  }
}
#endif

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace
}  // namespace HWY_NAMESPACE
}  // namespace jpegli
HWY_AFTER_NAMESPACE();
#endif  // LIB_JPEGLI_TRANSPOSE_INL_H_
