// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/upsample.h"

#include <string.h>

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jpegli/upsample.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

HWY_BEFORE_NAMESPACE();
namespace jpegli {
namespace HWY_NAMESPACE {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::Mul;
using hwy::HWY_NAMESPACE::MulAdd;
using hwy::HWY_NAMESPACE::Vec;

#if HWY_CAP_GE512
using hwy::HWY_NAMESPACE::Half;
using hwy::HWY_NAMESPACE::Vec;
template <size_t i, class DF, class V>
HWY_INLINE Vec<Half<Half<DF>>> Quarter(const DF df, V v) {
  using HF = Half<DF>;
  using HHF = Half<HF>;
  auto half = i >= 2 ? UpperHalf(HF(), v) : LowerHalf(HF(), v);
  return i & 1 ? UpperHalf(HHF(), half) : LowerHalf(HHF(), half);
}

template <class DF, class V>
HWY_INLINE Vec<DF> Concat4(const DF df, V v0, V v1, V v2, V v3) {
  using HF = Half<DF>;
  return Combine(DF(), Combine(HF(), v3, v2), Combine(HF(), v1, v0));
}

#endif

// Stores v0[0], v1[0], v0[1], v1[1], ... to mem, in this order. Mem must be
// aligned.
template <class DF, class V, typename T>
void StoreInterleaved(const DF df, V v0, V v1, T* mem) {
  static_assert(sizeof(T) == 4, "only use StoreInterleaved for 4-byte types");
#if HWY_TARGET == HWY_SCALAR
  Store(v0, df, mem);
  Store(v1, df, mem + 1);
#elif !HWY_CAP_GE256
  Store(InterleaveLower(df, v0, v1), df, mem);
  Store(InterleaveUpper(df, v0, v1), df, mem + Lanes(df));
#else
  if (!HWY_CAP_GE512 || Lanes(df) == 8) {
    auto t0 = InterleaveLower(df, v0, v1);
    auto t1 = InterleaveUpper(df, v0, v1);
    Store(ConcatLowerLower(df, t1, t0), df, mem);
    Store(ConcatUpperUpper(df, t1, t0), df, mem + Lanes(df));
  } else {
#if HWY_CAP_GE512
    auto t0 = InterleaveLower(df, v0, v1);
    auto t1 = InterleaveUpper(df, v0, v1);
    Store(Concat4(df, Quarter<0>(df, t0), Quarter<0>(df, t1),
                  Quarter<1>(df, t0), Quarter<1>(df, t1)),
          df, mem);
    Store(Concat4(df, Quarter<2>(df, t0), Quarter<2>(df, t1),
                  Quarter<3>(df, t0), Quarter<3>(df, t1)),
          df, mem + Lanes(df));
#endif
  }
#endif
}

void Upsample2Horizontal(float* JXL_RESTRICT row,
                         float* JXL_RESTRICT scratch_space, size_t len_out) {
  HWY_FULL(float) df;
  auto threefour = Set(df, 0.75f);
  auto onefour = Set(df, 0.25f);
  const size_t len_in = (len_out + 1) >> 1;
  memcpy(scratch_space, row, len_in * sizeof(row[0]));
  scratch_space[-1] = scratch_space[0];
  scratch_space[len_in] = scratch_space[len_in - 1];
  for (size_t x = 0; x < len_in; x += Lanes(df)) {
    auto current = Mul(Load(df, scratch_space + x), threefour);
    auto prev = LoadU(df, scratch_space + x - 1);
    auto next = LoadU(df, scratch_space + x + 1);
    auto left = MulAdd(onefour, prev, current);
    auto right = MulAdd(onefour, next, current);
    StoreInterleaved(df, left, right, row + x * 2);
  }
}

void Upsample2Vertical(const float* JXL_RESTRICT row_top,
                       const float* JXL_RESTRICT row_mid,
                       const float* JXL_RESTRICT row_bot,
                       float* JXL_RESTRICT row_out0,
                       float* JXL_RESTRICT row_out1, size_t len) {
  HWY_FULL(float) df;
  auto threefour = Set(df, 0.75f);
  auto onefour = Set(df, 0.25f);
  for (size_t x = 0; x < len; x += Lanes(df)) {
    auto it = Load(df, row_top + x);
    auto im = Load(df, row_mid + x);
    auto ib = Load(df, row_bot + x);
    auto im_scaled = Mul(im, threefour);
    Store(MulAdd(it, onefour, im_scaled), df, row_out0 + x);
    Store(MulAdd(ib, onefour, im_scaled), df, row_out1 + x);
  }
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jpegli
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jpegli {

HWY_EXPORT(Upsample2Horizontal);
HWY_EXPORT(Upsample2Vertical);

void Upsample2Horizontal(float* JXL_RESTRICT row,
                         float* JXL_RESTRICT scratch_space, size_t len_out) {
  return HWY_DYNAMIC_DISPATCH(Upsample2Horizontal)(row, scratch_space, len_out);
}

void Upsample2Vertical(const float* JXL_RESTRICT row_top,
                       const float* JXL_RESTRICT row_mid,
                       const float* JXL_RESTRICT row_bot,
                       float* JXL_RESTRICT row_out0,
                       float* JXL_RESTRICT row_out1, size_t len) {
  return HWY_DYNAMIC_DISPATCH(Upsample2Vertical)(row_top, row_mid, row_bot,
                                                 row_out0, row_out1, len);
}
}  // namespace jpegli
#endif  // HWY_ONCE
