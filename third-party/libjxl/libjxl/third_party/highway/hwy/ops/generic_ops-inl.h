// Copyright 2021 Google LLC
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Target-independent types/functions defined after target-specific ops.

#include "hwy/base.h"

// Define detail::Shuffle1230 etc, but only when viewing the current header;
// normally this is included via highway.h, which includes ops/*.h.
#if HWY_IDE && !defined(HWY_HIGHWAY_INCLUDED)
#include "hwy/detect_targets.h"
#include "hwy/ops/emu128-inl.h"
#endif  // HWY_IDE

// Relies on the external include guard in highway.h.
HWY_BEFORE_NAMESPACE();
namespace hwy {
namespace HWY_NAMESPACE {

// The lane type of a vector type, e.g. float for Vec<ScalableTag<float>>.
template <class V>
using LaneType = decltype(GetLane(V()));

// Vector type, e.g. Vec128<float> for CappedTag<float, 4>. Useful as the return
// type of functions that do not take a vector argument, or as an argument type
// if the function only has a template argument for D, or for explicit type
// names instead of auto. This may be a built-in type.
template <class D>
using Vec = decltype(Zero(D()));

// Mask type. Useful as the return type of functions that do not take a mask
// argument, or as an argument type if the function only has a template argument
// for D, or for explicit type names instead of auto.
template <class D>
using Mask = decltype(MaskFromVec(Zero(D())));

// Returns the closest value to v within [lo, hi].
template <class V>
HWY_API V Clamp(const V v, const V lo, const V hi) {
  return Min(Max(lo, v), hi);
}

// CombineShiftRightBytes (and -Lanes) are not available for the scalar target,
// and RVV has its own implementation of -Lanes.
#if HWY_TARGET != HWY_SCALAR && HWY_TARGET != HWY_RVV

template <size_t kLanes, class D>
HWY_API VFromD<D> CombineShiftRightLanes(D d, VFromD<D> hi, VFromD<D> lo) {
  constexpr size_t kBytes = kLanes * sizeof(TFromD<D>);
  static_assert(kBytes < 16, "Shift count is per-block");
  return CombineShiftRightBytes<kBytes>(d, hi, lo);
}

#endif

// Returns lanes with the most significant bit set and all other bits zero.
template <class D>
HWY_API Vec<D> SignBit(D d) {
  const RebindToUnsigned<decltype(d)> du;
  return BitCast(d, Set(du, SignMask<TFromD<D>>()));
}

// Returns quiet NaN.
template <class D>
HWY_API Vec<D> NaN(D d) {
  const RebindToSigned<D> di;
  // LimitsMax sets all exponent and mantissa bits to 1. The exponent plus
  // mantissa MSB (to indicate quiet) would be sufficient.
  return BitCast(d, Set(di, LimitsMax<TFromD<decltype(di)>>()));
}

// Returns positive infinity.
template <class D>
HWY_API Vec<D> Inf(D d) {
  const RebindToUnsigned<D> du;
  using T = TFromD<D>;
  using TU = TFromD<decltype(du)>;
  const TU max_x2 = static_cast<TU>(MaxExponentTimes2<T>());
  return BitCast(d, Set(du, max_x2 >> 1));
}

// ------------------------------ ZeroExtendResizeBitCast

// The implementation of detail::ZeroExtendResizeBitCast for the HWY_EMU128
// target is in emu128-inl.h, and the implementation of
// detail::ZeroExtendResizeBitCast for the HWY_SCALAR target is in scalar-inl.h
#if HWY_TARGET != HWY_EMU128 && HWY_TARGET != HWY_SCALAR
namespace detail {

#if HWY_HAVE_SCALABLE
template <size_t kFromVectSize, size_t kToVectSize, class DTo, class DFrom>
HWY_INLINE VFromD<DTo> ZeroExtendResizeBitCast(
    hwy::SizeTag<kFromVectSize> /* from_size_tag */,
    hwy::SizeTag<kToVectSize> /* to_size_tag */, DTo d_to, DFrom d_from,
    VFromD<DFrom> v) {
  const Repartition<uint8_t, DTo> d_to_u8;
  const auto resized = ResizeBitCast(d_to_u8, v);
  // Zero the upper bytes which were not present/valid in d_from.
  const size_t num_bytes = Lanes(Repartition<uint8_t, decltype(d_from)>());
  return BitCast(d_to, IfThenElseZero(FirstN(d_to_u8, num_bytes), resized));
}
#else   // target that uses fixed-size vectors
// Truncating or same-size resizing cast: same as ResizeBitCast
template <size_t kFromVectSize, size_t kToVectSize, class DTo, class DFrom,
          HWY_IF_LANES_LE(kToVectSize, kFromVectSize)>
HWY_INLINE VFromD<DTo> ZeroExtendResizeBitCast(
    hwy::SizeTag<kFromVectSize> /* from_size_tag */,
    hwy::SizeTag<kToVectSize> /* to_size_tag */, DTo d_to, DFrom /*d_from*/,
    VFromD<DFrom> v) {
  return ResizeBitCast(d_to, v);
}

// Resizing cast to vector that has twice the number of lanes of the source
// vector
template <size_t kFromVectSize, size_t kToVectSize, class DTo, class DFrom,
          HWY_IF_LANES(kToVectSize, kFromVectSize * 2)>
HWY_INLINE VFromD<DTo> ZeroExtendResizeBitCast(
    hwy::SizeTag<kFromVectSize> /* from_size_tag */,
    hwy::SizeTag<kToVectSize> /* to_size_tag */, DTo d_to, DFrom d_from,
    VFromD<DFrom> v) {
  const Twice<decltype(d_from)> dt_from;
  return BitCast(d_to, ZeroExtendVector(dt_from, v));
}

// Resizing cast to vector that has more than twice the number of lanes of the
// source vector
template <size_t kFromVectSize, size_t kToVectSize, class DTo, class DFrom,
          HWY_IF_LANES_GT(kToVectSize, kFromVectSize * 2)>
HWY_INLINE VFromD<DTo> ZeroExtendResizeBitCast(
    hwy::SizeTag<kFromVectSize> /* from_size_tag */,
    hwy::SizeTag<kToVectSize> /* to_size_tag */, DTo d_to, DFrom /*d_from*/,
    VFromD<DFrom> v) {
  using TFrom = TFromD<DFrom>;
  constexpr size_t kNumOfFromLanes = kFromVectSize / sizeof(TFrom);
  const Repartition<TFrom, decltype(d_to)> d_resize_to;
  return BitCast(d_to, IfThenElseZero(FirstN(d_resize_to, kNumOfFromLanes),
                                      ResizeBitCast(d_resize_to, v)));
}
#endif  // HWY_HAVE_SCALABLE

}  // namespace detail
#endif  // HWY_TARGET != HWY_EMU128 && HWY_TARGET != HWY_SCALAR

template <class DTo, class DFrom>
HWY_API VFromD<DTo> ZeroExtendResizeBitCast(DTo d_to, DFrom d_from,
                                            VFromD<DFrom> v) {
  return detail::ZeroExtendResizeBitCast(hwy::SizeTag<d_from.MaxBytes()>(),
                                         hwy::SizeTag<d_to.MaxBytes()>(), d_to,
                                         d_from, v);
}

// ------------------------------ SafeFillN

template <class D, typename T = TFromD<D>>
HWY_API void SafeFillN(const size_t num, const T value, D d,
                       T* HWY_RESTRICT to) {
#if HWY_MEM_OPS_MIGHT_FAULT
  (void)d;
  for (size_t i = 0; i < num; ++i) {
    to[i] = value;
  }
#else
  BlendedStore(Set(d, value), FirstN(d, num), d, to);
#endif
}

// ------------------------------ SafeCopyN

template <class D, typename T = TFromD<D>>
HWY_API void SafeCopyN(const size_t num, D d, const T* HWY_RESTRICT from,
                       T* HWY_RESTRICT to) {
#if HWY_MEM_OPS_MIGHT_FAULT
  (void)d;
  for (size_t i = 0; i < num; ++i) {
    to[i] = from[i];
  }
#else
  const Mask<D> mask = FirstN(d, num);
  BlendedStore(MaskedLoad(mask, d, from), mask, d, to);
#endif
}

// ------------------------------ BitwiseIfThenElse
#if (defined(HWY_NATIVE_BITWISE_IF_THEN_ELSE) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_BITWISE_IF_THEN_ELSE
#undef HWY_NATIVE_BITWISE_IF_THEN_ELSE
#else
#define HWY_NATIVE_BITWISE_IF_THEN_ELSE
#endif

template <class V>
HWY_API V BitwiseIfThenElse(V mask, V yes, V no) {
  return Or(And(mask, yes), AndNot(mask, no));
}

#endif  // HWY_NATIVE_BITWISE_IF_THEN_ELSE

// "Include guard": skip if native instructions are available. The generic
// implementation is currently shared between x86_* and wasm_*, and is too large
// to duplicate.

#if HWY_IDE || \
    (defined(HWY_NATIVE_LOAD_STORE_INTERLEAVED) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_LOAD_STORE_INTERLEAVED
#undef HWY_NATIVE_LOAD_STORE_INTERLEAVED
#else
#define HWY_NATIVE_LOAD_STORE_INTERLEAVED
#endif

// ------------------------------ LoadInterleaved2

template <class D, HWY_IF_LANES_GT_D(D, 1)>
HWY_API void LoadInterleaved2(D d, const TFromD<D>* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1) {
  const VFromD<D> A = LoadU(d, unaligned);  // v1[1] v0[1] v1[0] v0[0]
  const VFromD<D> B = LoadU(d, unaligned + Lanes(d));
  v0 = ConcatEven(d, B, A);
  v1 = ConcatOdd(d, B, A);
}

template <class D, HWY_IF_LANES_D(D, 1)>
HWY_API void LoadInterleaved2(D d, const TFromD<D>* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1) {
  v0 = LoadU(d, unaligned + 0);
  v1 = LoadU(d, unaligned + 1);
}

// ------------------------------ LoadInterleaved3 (CombineShiftRightBytes)

namespace detail {

#if HWY_IDE
template <class V>
HWY_INLINE V ShuffleTwo1230(V a, V /* b */) {
  return a;
}
template <class V>
HWY_INLINE V ShuffleTwo2301(V a, V /* b */) {
  return a;
}
template <class V>
HWY_INLINE V ShuffleTwo3012(V a, V /* b */) {
  return a;
}
#endif  // HWY_IDE

// Default for <= 128-bit vectors; x86_256 and x86_512 have their own overload.
template <class D, HWY_IF_V_SIZE_LE_D(D, 16)>
HWY_INLINE void LoadTransposedBlocks3(D d,
                                      const TFromD<D>* HWY_RESTRICT unaligned,
                                      VFromD<D>& A, VFromD<D>& B,
                                      VFromD<D>& C) {
  constexpr size_t kN = MaxLanes(d);
  A = LoadU(d, unaligned + 0 * kN);
  B = LoadU(d, unaligned + 1 * kN);
  C = LoadU(d, unaligned + 2 * kN);
}

}  // namespace detail

template <class D, HWY_IF_LANES_PER_BLOCK_D(D, 16)>
HWY_API void LoadInterleaved3(D d, const TFromD<D>* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1, VFromD<D>& v2) {
  const RebindToUnsigned<decltype(d)> du;
  using V = VFromD<D>;
  // Compact notation so these fit on one line: 12 := v1[2].
  V A;  // 05 24 14 04 23 13 03 22 12 02 21 11 01 20 10 00
  V B;  // 1a 0a 29 19 09 28 18 08 27 17 07 26 16 06 25 15
  V C;  // 2f 1f 0f 2e 1e 0e 2d 1d 0d 2c 1c 0c 2b 1b 0b 2a
  detail::LoadTransposedBlocks3(d, unaligned, A, B, C);
  // Compress all lanes belonging to v0 into consecutive lanes.
  constexpr uint8_t Z = 0x80;
  alignas(16) static constexpr uint8_t kIdx_v0A[16] = {
      0, 3, 6, 9, 12, 15, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v0B[16] = {
      Z, Z, Z, Z, Z, Z, 2, 5, 8, 11, 14, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v0C[16] = {
      Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, 1, 4, 7, 10, 13};
  alignas(16) static constexpr uint8_t kIdx_v1A[16] = {
      1, 4, 7, 10, 13, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v1B[16] = {
      Z, Z, Z, Z, Z, 0, 3, 6, 9, 12, 15, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v1C[16] = {
      Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, 2, 5, 8, 11, 14};
  alignas(16) static constexpr uint8_t kIdx_v2A[16] = {
      2, 5, 8, 11, 14, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v2B[16] = {
      Z, Z, Z, Z, Z, 1, 4, 7, 10, 13, Z, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v2C[16] = {
      Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, 0, 3, 6, 9, 12, 15};
  const V v0L = BitCast(d, TableLookupBytesOr0(A, LoadDup128(du, kIdx_v0A)));
  const V v0M = BitCast(d, TableLookupBytesOr0(B, LoadDup128(du, kIdx_v0B)));
  const V v0U = BitCast(d, TableLookupBytesOr0(C, LoadDup128(du, kIdx_v0C)));
  const V v1L = BitCast(d, TableLookupBytesOr0(A, LoadDup128(du, kIdx_v1A)));
  const V v1M = BitCast(d, TableLookupBytesOr0(B, LoadDup128(du, kIdx_v1B)));
  const V v1U = BitCast(d, TableLookupBytesOr0(C, LoadDup128(du, kIdx_v1C)));
  const V v2L = BitCast(d, TableLookupBytesOr0(A, LoadDup128(du, kIdx_v2A)));
  const V v2M = BitCast(d, TableLookupBytesOr0(B, LoadDup128(du, kIdx_v2B)));
  const V v2U = BitCast(d, TableLookupBytesOr0(C, LoadDup128(du, kIdx_v2C)));
  v0 = Xor3(v0L, v0M, v0U);
  v1 = Xor3(v1L, v1M, v1U);
  v2 = Xor3(v2L, v2M, v2U);
}

// 8-bit lanes x8
template <class D, HWY_IF_LANES_PER_BLOCK_D(D, 8), HWY_IF_T_SIZE_D(D, 1)>
HWY_API void LoadInterleaved3(D d, const TFromD<D>* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1, VFromD<D>& v2) {
  const RebindToUnsigned<decltype(d)> du;
  using V = VFromD<D>;
  V A;  // v1[2] v0[2] v2[1] v1[1] v0[1] v2[0] v1[0] v0[0]
  V B;  // v0[5] v2[4] v1[4] v0[4] v2[3] v1[3] v0[3] v2[2]
  V C;  // v2[7] v1[7] v0[7] v2[6] v1[6] v0[6] v2[5] v1[5]
  detail::LoadTransposedBlocks3(d, unaligned, A, B, C);
  // Compress all lanes belonging to v0 into consecutive lanes.
  constexpr uint8_t Z = 0x80;
  alignas(16) static constexpr uint8_t kIdx_v0A[16] = {0, 3, 6, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v0B[16] = {Z, Z, Z, 1, 4, 7, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v0C[16] = {Z, Z, Z, Z, Z, Z, 2, 5};
  alignas(16) static constexpr uint8_t kIdx_v1A[16] = {1, 4, 7, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v1B[16] = {Z, Z, Z, 2, 5, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v1C[16] = {Z, Z, Z, Z, Z, 0, 3, 6};
  alignas(16) static constexpr uint8_t kIdx_v2A[16] = {2, 5, Z, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v2B[16] = {Z, Z, 0, 3, 6, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v2C[16] = {Z, Z, Z, Z, Z, 1, 4, 7};
  const V v0L = BitCast(d, TableLookupBytesOr0(A, LoadDup128(du, kIdx_v0A)));
  const V v0M = BitCast(d, TableLookupBytesOr0(B, LoadDup128(du, kIdx_v0B)));
  const V v0U = BitCast(d, TableLookupBytesOr0(C, LoadDup128(du, kIdx_v0C)));
  const V v1L = BitCast(d, TableLookupBytesOr0(A, LoadDup128(du, kIdx_v1A)));
  const V v1M = BitCast(d, TableLookupBytesOr0(B, LoadDup128(du, kIdx_v1B)));
  const V v1U = BitCast(d, TableLookupBytesOr0(C, LoadDup128(du, kIdx_v1C)));
  const V v2L = BitCast(d, TableLookupBytesOr0(A, LoadDup128(du, kIdx_v2A)));
  const V v2M = BitCast(d, TableLookupBytesOr0(B, LoadDup128(du, kIdx_v2B)));
  const V v2U = BitCast(d, TableLookupBytesOr0(C, LoadDup128(du, kIdx_v2C)));
  v0 = Xor3(v0L, v0M, v0U);
  v1 = Xor3(v1L, v1M, v1U);
  v2 = Xor3(v2L, v2M, v2U);
}

// 16-bit lanes x8
template <class D, HWY_IF_LANES_PER_BLOCK_D(D, 8), HWY_IF_T_SIZE_D(D, 2)>
HWY_API void LoadInterleaved3(D d, const TFromD<D>* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1, VFromD<D>& v2) {
  const RebindToUnsigned<decltype(d)> du;
  const Repartition<uint8_t, decltype(du)> du8;
  using V = VFromD<D>;
  V A;  // v1[2] v0[2] v2[1] v1[1] v0[1] v2[0] v1[0] v0[0]
  V B;  // v0[5] v2[4] v1[4] v0[4] v2[3] v1[3] v0[3] v2[2]
  V C;  // v2[7] v1[7] v0[7] v2[6] v1[6] v0[6] v2[5] v1[5]
  detail::LoadTransposedBlocks3(d, unaligned, A, B, C);
  // Compress all lanes belonging to v0 into consecutive lanes. Same as above,
  // but each element of the array contains a byte index for a byte of a lane.
  constexpr uint8_t Z = 0x80;
  alignas(16) static constexpr uint8_t kIdx_v0A[16] = {
      0x00, 0x01, 0x06, 0x07, 0x0C, 0x0D, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v0B[16] = {
      Z, Z, Z, Z, Z, Z, 0x02, 0x03, 0x08, 0x09, 0x0E, 0x0F, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v0C[16] = {
      Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, 0x04, 0x05, 0x0A, 0x0B};
  alignas(16) static constexpr uint8_t kIdx_v1A[16] = {
      0x02, 0x03, 0x08, 0x09, 0x0E, 0x0F, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v1B[16] = {
      Z, Z, Z, Z, Z, Z, 0x04, 0x05, 0x0A, 0x0B, Z, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v1C[16] = {
      Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, 0x00, 0x01, 0x06, 0x07, 0x0C, 0x0D};
  alignas(16) static constexpr uint8_t kIdx_v2A[16] = {
      0x04, 0x05, 0x0A, 0x0B, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v2B[16] = {
      Z, Z, Z, Z, 0x00, 0x01, 0x06, 0x07, 0x0C, 0x0D, Z, Z, Z, Z, Z, Z};
  alignas(16) static constexpr uint8_t kIdx_v2C[16] = {
      Z, Z, Z, Z, Z, Z, Z, Z, Z, Z, 0x02, 0x03, 0x08, 0x09, 0x0E, 0x0F};
  const V v0L = TableLookupBytesOr0(A, BitCast(d, LoadDup128(du8, kIdx_v0A)));
  const V v0M = TableLookupBytesOr0(B, BitCast(d, LoadDup128(du8, kIdx_v0B)));
  const V v0U = TableLookupBytesOr0(C, BitCast(d, LoadDup128(du8, kIdx_v0C)));
  const V v1L = TableLookupBytesOr0(A, BitCast(d, LoadDup128(du8, kIdx_v1A)));
  const V v1M = TableLookupBytesOr0(B, BitCast(d, LoadDup128(du8, kIdx_v1B)));
  const V v1U = TableLookupBytesOr0(C, BitCast(d, LoadDup128(du8, kIdx_v1C)));
  const V v2L = TableLookupBytesOr0(A, BitCast(d, LoadDup128(du8, kIdx_v2A)));
  const V v2M = TableLookupBytesOr0(B, BitCast(d, LoadDup128(du8, kIdx_v2B)));
  const V v2U = TableLookupBytesOr0(C, BitCast(d, LoadDup128(du8, kIdx_v2C)));
  v0 = Xor3(v0L, v0M, v0U);
  v1 = Xor3(v1L, v1M, v1U);
  v2 = Xor3(v2L, v2M, v2U);
}

template <class D, HWY_IF_LANES_PER_BLOCK_D(D, 4)>
HWY_API void LoadInterleaved3(D d, const TFromD<D>* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1, VFromD<D>& v2) {
  using V = VFromD<D>;
  V A;  // v0[1] v2[0] v1[0] v0[0]
  V B;  // v1[2] v0[2] v2[1] v1[1]
  V C;  // v2[3] v1[3] v0[3] v2[2]
  detail::LoadTransposedBlocks3(d, unaligned, A, B, C);

  const V vxx_02_03_xx = OddEven(C, B);
  v0 = detail::ShuffleTwo1230(A, vxx_02_03_xx);

  // Shuffle2301 takes the upper/lower halves of the output from one input, so
  // we cannot just combine 13 and 10 with 12 and 11 (similar to v0/v2). Use
  // OddEven because it may have higher throughput than Shuffle.
  const V vxx_xx_10_11 = OddEven(A, B);
  const V v12_13_xx_xx = OddEven(B, C);
  v1 = detail::ShuffleTwo2301(vxx_xx_10_11, v12_13_xx_xx);

  const V vxx_20_21_xx = OddEven(B, A);
  v2 = detail::ShuffleTwo3012(vxx_20_21_xx, C);
}

template <class D, HWY_IF_LANES_PER_BLOCK_D(D, 2)>
HWY_API void LoadInterleaved3(D d, const TFromD<D>* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1, VFromD<D>& v2) {
  VFromD<D> A;  // v1[0] v0[0]
  VFromD<D> B;  // v0[1] v2[0]
  VFromD<D> C;  // v2[1] v1[1]
  detail::LoadTransposedBlocks3(d, unaligned, A, B, C);
  v0 = OddEven(B, A);
  v1 = CombineShiftRightBytes<sizeof(TFromD<D>)>(d, C, A);
  v2 = OddEven(C, B);
}

template <class D, typename T = TFromD<D>, HWY_IF_LANES_D(D, 1)>
HWY_API void LoadInterleaved3(D d, const T* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1, VFromD<D>& v2) {
  v0 = LoadU(d, unaligned + 0);
  v1 = LoadU(d, unaligned + 1);
  v2 = LoadU(d, unaligned + 2);
}

// ------------------------------ LoadInterleaved4

namespace detail {

// Default for <= 128-bit vectors; x86_256 and x86_512 have their own overload.
template <class D, HWY_IF_V_SIZE_LE_D(D, 16)>
HWY_INLINE void LoadTransposedBlocks4(D d,
                                      const TFromD<D>* HWY_RESTRICT unaligned,
                                      VFromD<D>& vA, VFromD<D>& vB,
                                      VFromD<D>& vC, VFromD<D>& vD) {
  constexpr size_t kN = MaxLanes(d);
  vA = LoadU(d, unaligned + 0 * kN);
  vB = LoadU(d, unaligned + 1 * kN);
  vC = LoadU(d, unaligned + 2 * kN);
  vD = LoadU(d, unaligned + 3 * kN);
}

}  // namespace detail

template <class D, HWY_IF_LANES_PER_BLOCK_D(D, 16)>
HWY_API void LoadInterleaved4(D d, const TFromD<D>* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1, VFromD<D>& v2,
                              VFromD<D>& v3) {
  const Repartition<uint64_t, decltype(d)> d64;
  using V64 = VFromD<decltype(d64)>;
  using V = VFromD<D>;
  // 16 lanes per block; the lowest four blocks are at the bottom of vA..vD.
  // Here int[i] means the four interleaved values of the i-th 4-tuple and
  // int[3..0] indicates four consecutive 4-tuples (0 = least-significant).
  V vA;  // int[13..10] int[3..0]
  V vB;  // int[17..14] int[7..4]
  V vC;  // int[1b..18] int[b..8]
  V vD;  // int[1f..1c] int[f..c]
  detail::LoadTransposedBlocks4(d, unaligned, vA, vB, vC, vD);

  // For brevity, the comments only list the lower block (upper = lower + 0x10)
  const V v5140 = InterleaveLower(d, vA, vB);  // int[5,1,4,0]
  const V vd9c8 = InterleaveLower(d, vC, vD);  // int[d,9,c,8]
  const V v7362 = InterleaveUpper(d, vA, vB);  // int[7,3,6,2]
  const V vfbea = InterleaveUpper(d, vC, vD);  // int[f,b,e,a]

  const V v6420 = InterleaveLower(d, v5140, v7362);  // int[6,4,2,0]
  const V veca8 = InterleaveLower(d, vd9c8, vfbea);  // int[e,c,a,8]
  const V v7531 = InterleaveUpper(d, v5140, v7362);  // int[7,5,3,1]
  const V vfdb9 = InterleaveUpper(d, vd9c8, vfbea);  // int[f,d,b,9]

  const V64 v10L = BitCast(d64, InterleaveLower(d, v6420, v7531));  // v10[7..0]
  const V64 v10U = BitCast(d64, InterleaveLower(d, veca8, vfdb9));  // v10[f..8]
  const V64 v32L = BitCast(d64, InterleaveUpper(d, v6420, v7531));  // v32[7..0]
  const V64 v32U = BitCast(d64, InterleaveUpper(d, veca8, vfdb9));  // v32[f..8]

  v0 = BitCast(d, InterleaveLower(d64, v10L, v10U));
  v1 = BitCast(d, InterleaveUpper(d64, v10L, v10U));
  v2 = BitCast(d, InterleaveLower(d64, v32L, v32U));
  v3 = BitCast(d, InterleaveUpper(d64, v32L, v32U));
}

template <class D, HWY_IF_LANES_PER_BLOCK_D(D, 8)>
HWY_API void LoadInterleaved4(D d, const TFromD<D>* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1, VFromD<D>& v2,
                              VFromD<D>& v3) {
  // In the last step, we interleave by half of the block size, which is usually
  // 8 bytes but half that for 8-bit x8 vectors.
  using TW = hwy::UnsignedFromSize<d.MaxBytes() == 8 ? 4 : 8>;
  const Repartition<TW, decltype(d)> dw;
  using VW = VFromD<decltype(dw)>;

  // (Comments are for 256-bit vectors.)
  // 8 lanes per block; the lowest four blocks are at the bottom of vA..vD.
  VFromD<D> vA;  // v3210[9]v3210[8] v3210[1]v3210[0]
  VFromD<D> vB;  // v3210[b]v3210[a] v3210[3]v3210[2]
  VFromD<D> vC;  // v3210[d]v3210[c] v3210[5]v3210[4]
  VFromD<D> vD;  // v3210[f]v3210[e] v3210[7]v3210[6]
  detail::LoadTransposedBlocks4(d, unaligned, vA, vB, vC, vD);

  const VFromD<D> va820 = InterleaveLower(d, vA, vB);  // v3210[a,8] v3210[2,0]
  const VFromD<D> vec64 = InterleaveLower(d, vC, vD);  // v3210[e,c] v3210[6,4]
  const VFromD<D> vb931 = InterleaveUpper(d, vA, vB);  // v3210[b,9] v3210[3,1]
  const VFromD<D> vfd75 = InterleaveUpper(d, vC, vD);  // v3210[f,d] v3210[7,5]

  const VW v10_b830 =  // v10[b..8] v10[3..0]
      BitCast(dw, InterleaveLower(d, va820, vb931));
  const VW v10_fc74 =  // v10[f..c] v10[7..4]
      BitCast(dw, InterleaveLower(d, vec64, vfd75));
  const VW v32_b830 =  // v32[b..8] v32[3..0]
      BitCast(dw, InterleaveUpper(d, va820, vb931));
  const VW v32_fc74 =  // v32[f..c] v32[7..4]
      BitCast(dw, InterleaveUpper(d, vec64, vfd75));

  v0 = BitCast(d, InterleaveLower(dw, v10_b830, v10_fc74));
  v1 = BitCast(d, InterleaveUpper(dw, v10_b830, v10_fc74));
  v2 = BitCast(d, InterleaveLower(dw, v32_b830, v32_fc74));
  v3 = BitCast(d, InterleaveUpper(dw, v32_b830, v32_fc74));
}

template <class D, HWY_IF_LANES_PER_BLOCK_D(D, 4)>
HWY_API void LoadInterleaved4(D d, const TFromD<D>* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1, VFromD<D>& v2,
                              VFromD<D>& v3) {
  using V = VFromD<D>;
  V vA;  // v3210[4] v3210[0]
  V vB;  // v3210[5] v3210[1]
  V vC;  // v3210[6] v3210[2]
  V vD;  // v3210[7] v3210[3]
  detail::LoadTransposedBlocks4(d, unaligned, vA, vB, vC, vD);
  const V v10e = InterleaveLower(d, vA, vC);  // v1[6,4] v0[6,4] v1[2,0] v0[2,0]
  const V v10o = InterleaveLower(d, vB, vD);  // v1[7,5] v0[7,5] v1[3,1] v0[3,1]
  const V v32e = InterleaveUpper(d, vA, vC);  // v3[6,4] v2[6,4] v3[2,0] v2[2,0]
  const V v32o = InterleaveUpper(d, vB, vD);  // v3[7,5] v2[7,5] v3[3,1] v2[3,1]

  v0 = InterleaveLower(d, v10e, v10o);
  v1 = InterleaveUpper(d, v10e, v10o);
  v2 = InterleaveLower(d, v32e, v32o);
  v3 = InterleaveUpper(d, v32e, v32o);
}

template <class D, HWY_IF_LANES_PER_BLOCK_D(D, 2)>
HWY_API void LoadInterleaved4(D d, const TFromD<D>* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1, VFromD<D>& v2,
                              VFromD<D>& v3) {
  VFromD<D> vA, vB, vC, vD;
  detail::LoadTransposedBlocks4(d, unaligned, vA, vB, vC, vD);
  v0 = InterleaveLower(d, vA, vC);
  v1 = InterleaveUpper(d, vA, vC);
  v2 = InterleaveLower(d, vB, vD);
  v3 = InterleaveUpper(d, vB, vD);
}

// Any T x1
template <class D, typename T = TFromD<D>, HWY_IF_LANES_D(D, 1)>
HWY_API void LoadInterleaved4(D d, const T* HWY_RESTRICT unaligned,
                              VFromD<D>& v0, VFromD<D>& v1, VFromD<D>& v2,
                              VFromD<D>& v3) {
  v0 = LoadU(d, unaligned + 0);
  v1 = LoadU(d, unaligned + 1);
  v2 = LoadU(d, unaligned + 2);
  v3 = LoadU(d, unaligned + 3);
}

// ------------------------------ StoreInterleaved2

namespace detail {

// Default for <= 128-bit vectors; x86_256 and x86_512 have their own overload.
template <class D, HWY_IF_V_SIZE_LE_D(D, 16)>
HWY_INLINE void StoreTransposedBlocks2(VFromD<D> A, VFromD<D> B, D d,
                                       TFromD<D>* HWY_RESTRICT unaligned) {
  constexpr size_t kN = MaxLanes(d);
  StoreU(A, d, unaligned + 0 * kN);
  StoreU(B, d, unaligned + 1 * kN);
}

}  // namespace detail

// >= 128 bit vector
template <class D, HWY_IF_V_SIZE_GT_D(D, 8)>
HWY_API void StoreInterleaved2(VFromD<D> v0, VFromD<D> v1, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  const auto v10L = InterleaveLower(d, v0, v1);  // .. v1[0] v0[0]
  const auto v10U = InterleaveUpper(d, v0, v1);  // .. v1[kN/2] v0[kN/2]
  detail::StoreTransposedBlocks2(v10L, v10U, d, unaligned);
}

// <= 64 bits
template <class V, class D, HWY_IF_V_SIZE_LE_D(D, 8)>
HWY_API void StoreInterleaved2(V part0, V part1, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  const Twice<decltype(d)> d2;
  const auto v0 = ZeroExtendVector(d2, part0);
  const auto v1 = ZeroExtendVector(d2, part1);
  const auto v10 = InterleaveLower(d2, v0, v1);
  StoreU(v10, d2, unaligned);
}

// ------------------------------ StoreInterleaved3 (CombineShiftRightBytes,
// TableLookupBytes)

namespace detail {

// Default for <= 128-bit vectors; x86_256 and x86_512 have their own overload.
template <class D, HWY_IF_V_SIZE_LE_D(D, 16)>
HWY_INLINE void StoreTransposedBlocks3(VFromD<D> A, VFromD<D> B, VFromD<D> C,
                                       D d, TFromD<D>* HWY_RESTRICT unaligned) {
  constexpr size_t kN = MaxLanes(d);
  StoreU(A, d, unaligned + 0 * kN);
  StoreU(B, d, unaligned + 1 * kN);
  StoreU(C, d, unaligned + 2 * kN);
}

}  // namespace detail

// >= 128-bit vector, 8-bit lanes
template <class D, HWY_IF_T_SIZE_D(D, 1), HWY_IF_V_SIZE_GT_D(D, 8)>
HWY_API void StoreInterleaved3(VFromD<D> v0, VFromD<D> v1, VFromD<D> v2, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  const RebindToUnsigned<decltype(d)> du;
  using TU = TFromD<decltype(du)>;
  const auto k5 = Set(du, TU{5});
  const auto k6 = Set(du, TU{6});

  // Interleave (v0,v1,v2) to (MSB on left, lane 0 on right):
  // v0[5], v2[4],v1[4],v0[4] .. v2[0],v1[0],v0[0]. We're expanding v0 lanes
  // to their place, with 0x80 so lanes to be filled from other vectors are 0
  // to enable blending by ORing together.
  alignas(16) static constexpr uint8_t tbl_v0[16] = {
      0, 0x80, 0x80, 1, 0x80, 0x80, 2, 0x80, 0x80,  //
      3, 0x80, 0x80, 4, 0x80, 0x80, 5};
  alignas(16) static constexpr uint8_t tbl_v1[16] = {
      0x80, 0, 0x80, 0x80, 1, 0x80,  //
      0x80, 2, 0x80, 0x80, 3, 0x80, 0x80, 4, 0x80, 0x80};
  // The interleaved vectors will be named A, B, C; temporaries with suffix
  // 0..2 indicate which input vector's lanes they hold.
  const auto shuf_A0 = LoadDup128(du, tbl_v0);
  const auto shuf_A1 = LoadDup128(du, tbl_v1);  // cannot reuse shuf_A0 (has 5)
  const auto shuf_A2 = CombineShiftRightBytes<15>(du, shuf_A1, shuf_A1);
  const auto A0 = TableLookupBytesOr0(v0, shuf_A0);  // 5..4..3..2..1..0
  const auto A1 = TableLookupBytesOr0(v1, shuf_A1);  // ..4..3..2..1..0.
  const auto A2 = TableLookupBytesOr0(v2, shuf_A2);  // .4..3..2..1..0..
  const VFromD<D> A = BitCast(d, A0 | A1 | A2);

  // B: v1[10],v0[10], v2[9],v1[9],v0[9] .. , v2[6],v1[6],v0[6], v2[5],v1[5]
  const auto shuf_B0 = shuf_A2 + k6;  // .A..9..8..7..6..
  const auto shuf_B1 = shuf_A0 + k5;  // A..9..8..7..6..5
  const auto shuf_B2 = shuf_A1 + k5;  // ..9..8..7..6..5.
  const auto B0 = TableLookupBytesOr0(v0, shuf_B0);
  const auto B1 = TableLookupBytesOr0(v1, shuf_B1);
  const auto B2 = TableLookupBytesOr0(v2, shuf_B2);
  const VFromD<D> B = BitCast(d, B0 | B1 | B2);

  // C: v2[15],v1[15],v0[15], v2[11],v1[11],v0[11], v2[10]
  const auto shuf_C0 = shuf_B2 + k6;  // ..F..E..D..C..B.
  const auto shuf_C1 = shuf_B0 + k5;  // .F..E..D..C..B..
  const auto shuf_C2 = shuf_B1 + k5;  // F..E..D..C..B..A
  const auto C0 = TableLookupBytesOr0(v0, shuf_C0);
  const auto C1 = TableLookupBytesOr0(v1, shuf_C1);
  const auto C2 = TableLookupBytesOr0(v2, shuf_C2);
  const VFromD<D> C = BitCast(d, C0 | C1 | C2);

  detail::StoreTransposedBlocks3(A, B, C, d, unaligned);
}

// >= 128-bit vector, 16-bit lanes
template <class D, HWY_IF_T_SIZE_D(D, 2), HWY_IF_V_SIZE_GT_D(D, 8)>
HWY_API void StoreInterleaved3(VFromD<D> v0, VFromD<D> v1, VFromD<D> v2, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  const Repartition<uint8_t, decltype(d)> du8;
  const auto k2 = Set(du8, uint8_t{2 * sizeof(TFromD<D>)});
  const auto k3 = Set(du8, uint8_t{3 * sizeof(TFromD<D>)});

  // Interleave (v0,v1,v2) to (MSB on left, lane 0 on right):
  // v1[2],v0[2], v2[1],v1[1],v0[1], v2[0],v1[0],v0[0]. 0x80 so lanes to be
  // filled from other vectors are 0 for blending. Note that these are byte
  // indices for 16-bit lanes.
  alignas(16) static constexpr uint8_t tbl_v1[16] = {
      0x80, 0x80, 0,    1,    0x80, 0x80, 0x80, 0x80,
      2,    3,    0x80, 0x80, 0x80, 0x80, 4,    5};
  alignas(16) static constexpr uint8_t tbl_v2[16] = {
      0x80, 0x80, 0x80, 0x80, 0,    1,    0x80, 0x80,
      0x80, 0x80, 2,    3,    0x80, 0x80, 0x80, 0x80};

  // The interleaved vectors will be named A, B, C; temporaries with suffix
  // 0..2 indicate which input vector's lanes they hold.
  const auto shuf_A1 = LoadDup128(du8, tbl_v1);  // 2..1..0.
                                                 // .2..1..0
  const auto shuf_A0 = CombineShiftRightBytes<2>(du8, shuf_A1, shuf_A1);
  const auto shuf_A2 = LoadDup128(du8, tbl_v2);  // ..1..0..

  const auto A0 = TableLookupBytesOr0(v0, shuf_A0);
  const auto A1 = TableLookupBytesOr0(v1, shuf_A1);
  const auto A2 = TableLookupBytesOr0(v2, shuf_A2);
  const VFromD<D> A = BitCast(d, A0 | A1 | A2);

  // B: v0[5] v2[4],v1[4],v0[4], v2[3],v1[3],v0[3], v2[2]
  const auto shuf_B0 = shuf_A1 + k3;  // 5..4..3.
  const auto shuf_B1 = shuf_A2 + k3;  // ..4..3..
  const auto shuf_B2 = shuf_A0 + k2;  // .4..3..2
  const auto B0 = TableLookupBytesOr0(v0, shuf_B0);
  const auto B1 = TableLookupBytesOr0(v1, shuf_B1);
  const auto B2 = TableLookupBytesOr0(v2, shuf_B2);
  const VFromD<D> B = BitCast(d, B0 | B1 | B2);

  // C: v2[7],v1[7],v0[7], v2[6],v1[6],v0[6], v2[5],v1[5]
  const auto shuf_C0 = shuf_B1 + k3;  // ..7..6..
  const auto shuf_C1 = shuf_B2 + k3;  // .7..6..5
  const auto shuf_C2 = shuf_B0 + k2;  // 7..6..5.
  const auto C0 = TableLookupBytesOr0(v0, shuf_C0);
  const auto C1 = TableLookupBytesOr0(v1, shuf_C1);
  const auto C2 = TableLookupBytesOr0(v2, shuf_C2);
  const VFromD<D> C = BitCast(d, C0 | C1 | C2);

  detail::StoreTransposedBlocks3(A, B, C, d, unaligned);
}

// >= 128-bit vector, 32-bit lanes
template <class D, HWY_IF_T_SIZE_D(D, 4), HWY_IF_V_SIZE_GT_D(D, 8)>
HWY_API void StoreInterleaved3(VFromD<D> v0, VFromD<D> v1, VFromD<D> v2, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  const RepartitionToWide<decltype(d)> dw;

  const VFromD<D> v10_v00 = InterleaveLower(d, v0, v1);
  const VFromD<D> v01_v20 = OddEven(v0, v2);
  // A: v0[1], v2[0],v1[0],v0[0] (<- lane 0)
  const VFromD<D> A = BitCast(
      d, InterleaveLower(dw, BitCast(dw, v10_v00), BitCast(dw, v01_v20)));

  const VFromD<D> v1_321 = ShiftRightLanes<1>(d, v1);
  const VFromD<D> v0_32 = ShiftRightLanes<2>(d, v0);
  const VFromD<D> v21_v11 = OddEven(v2, v1_321);
  const VFromD<D> v12_v02 = OddEven(v1_321, v0_32);
  // B: v1[2],v0[2], v2[1],v1[1]
  const VFromD<D> B = BitCast(
      d, InterleaveLower(dw, BitCast(dw, v21_v11), BitCast(dw, v12_v02)));

  // Notation refers to the upper 2 lanes of the vector for InterleaveUpper.
  const VFromD<D> v23_v13 = OddEven(v2, v1_321);
  const VFromD<D> v03_v22 = OddEven(v0, v2);
  // C: v2[3],v1[3],v0[3], v2[2]
  const VFromD<D> C = BitCast(
      d, InterleaveUpper(dw, BitCast(dw, v03_v22), BitCast(dw, v23_v13)));

  detail::StoreTransposedBlocks3(A, B, C, d, unaligned);
}

// >= 128-bit vector, 64-bit lanes
template <class D, HWY_IF_T_SIZE_D(D, 8), HWY_IF_V_SIZE_GT_D(D, 8)>
HWY_API void StoreInterleaved3(VFromD<D> v0, VFromD<D> v1, VFromD<D> v2, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  const VFromD<D> A = InterleaveLower(d, v0, v1);
  const VFromD<D> B = OddEven(v0, v2);
  const VFromD<D> C = InterleaveUpper(d, v1, v2);
  detail::StoreTransposedBlocks3(A, B, C, d, unaligned);
}

// 64-bit vector, 8-bit lanes
template <class D, HWY_IF_T_SIZE_D(D, 1), HWY_IF_V_SIZE_D(D, 8)>
HWY_API void StoreInterleaved3(VFromD<D> part0, VFromD<D> part1,
                               VFromD<D> part2, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  // Use full vectors for the shuffles and first result.
  constexpr size_t kFullN = 16 / sizeof(TFromD<D>);
  const Full128<uint8_t> du;
  const Full128<TFromD<D>> d_full;
  const auto k5 = Set(du, uint8_t{5});
  const auto k6 = Set(du, uint8_t{6});

  const VFromD<decltype(d_full)> v0{part0.raw};
  const VFromD<decltype(d_full)> v1{part1.raw};
  const VFromD<decltype(d_full)> v2{part2.raw};

  // Interleave (v0,v1,v2) to (MSB on left, lane 0 on right):
  // v1[2],v0[2], v2[1],v1[1],v0[1], v2[0],v1[0],v0[0]. 0x80 so lanes to be
  // filled from other vectors are 0 for blending.
  alignas(16) static constexpr uint8_t tbl_v0[16] = {
      0, 0x80, 0x80, 1, 0x80, 0x80, 2, 0x80, 0x80,  //
      3, 0x80, 0x80, 4, 0x80, 0x80, 5};
  alignas(16) static constexpr uint8_t tbl_v1[16] = {
      0x80, 0, 0x80, 0x80, 1, 0x80,  //
      0x80, 2, 0x80, 0x80, 3, 0x80, 0x80, 4, 0x80, 0x80};
  // The interleaved vectors will be named A, B, C; temporaries with suffix
  // 0..2 indicate which input vector's lanes they hold.
  const auto shuf_A0 = Load(du, tbl_v0);
  const auto shuf_A1 = Load(du, tbl_v1);  // cannot reuse shuf_A0 (5 in MSB)
  const auto shuf_A2 = CombineShiftRightBytes<15>(du, shuf_A1, shuf_A1);
  const auto A0 = TableLookupBytesOr0(v0, shuf_A0);  // 5..4..3..2..1..0
  const auto A1 = TableLookupBytesOr0(v1, shuf_A1);  // ..4..3..2..1..0.
  const auto A2 = TableLookupBytesOr0(v2, shuf_A2);  // .4..3..2..1..0..
  const auto A = BitCast(d_full, A0 | A1 | A2);
  StoreU(A, d_full, unaligned + 0 * kFullN);

  // Second (HALF) vector: v2[7],v1[7],v0[7], v2[6],v1[6],v0[6], v2[5],v1[5]
  const auto shuf_B0 = shuf_A2 + k6;  // ..7..6..
  const auto shuf_B1 = shuf_A0 + k5;  // .7..6..5
  const auto shuf_B2 = shuf_A1 + k5;  // 7..6..5.
  const auto B0 = TableLookupBytesOr0(v0, shuf_B0);
  const auto B1 = TableLookupBytesOr0(v1, shuf_B1);
  const auto B2 = TableLookupBytesOr0(v2, shuf_B2);
  const VFromD<D> B{BitCast(d_full, B0 | B1 | B2).raw};
  StoreU(B, d, unaligned + 1 * kFullN);
}

// 64-bit vector, 16-bit lanes
template <class D, HWY_IF_T_SIZE_D(D, 2), HWY_IF_LANES_D(D, 4)>
HWY_API void StoreInterleaved3(VFromD<D> part0, VFromD<D> part1,
                               VFromD<D> part2, D dh,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  const Twice<D> d_full;
  const Full128<uint8_t> du8;
  const auto k2 = Set(du8, uint8_t{2 * sizeof(TFromD<D>)});
  const auto k3 = Set(du8, uint8_t{3 * sizeof(TFromD<D>)});

  const VFromD<decltype(d_full)> v0{part0.raw};
  const VFromD<decltype(d_full)> v1{part1.raw};
  const VFromD<decltype(d_full)> v2{part2.raw};

  // Interleave part (v0,v1,v2) to full (MSB on left, lane 0 on right):
  // v1[2],v0[2], v2[1],v1[1],v0[1], v2[0],v1[0],v0[0]. We're expanding v0 lanes
  // to their place, with 0x80 so lanes to be filled from other vectors are 0
  // to enable blending by ORing together.
  alignas(16) static constexpr uint8_t tbl_v1[16] = {
      0x80, 0x80, 0,    1,    0x80, 0x80, 0x80, 0x80,
      2,    3,    0x80, 0x80, 0x80, 0x80, 4,    5};
  alignas(16) static constexpr uint8_t tbl_v2[16] = {
      0x80, 0x80, 0x80, 0x80, 0,    1,    0x80, 0x80,
      0x80, 0x80, 2,    3,    0x80, 0x80, 0x80, 0x80};

  // The interleaved vectors will be named A, B; temporaries with suffix
  // 0..2 indicate which input vector's lanes they hold.
  const auto shuf_A1 = Load(du8, tbl_v1);  // 2..1..0.
                                           // .2..1..0
  const auto shuf_A0 = CombineShiftRightBytes<2>(du8, shuf_A1, shuf_A1);
  const auto shuf_A2 = Load(du8, tbl_v2);  // ..1..0..

  const auto A0 = TableLookupBytesOr0(v0, shuf_A0);
  const auto A1 = TableLookupBytesOr0(v1, shuf_A1);
  const auto A2 = TableLookupBytesOr0(v2, shuf_A2);
  const VFromD<decltype(d_full)> A = BitCast(d_full, A0 | A1 | A2);
  StoreU(A, d_full, unaligned);

  // Second (HALF) vector: v2[3],v1[3],v0[3], v2[2]
  const auto shuf_B0 = shuf_A1 + k3;  // ..3.
  const auto shuf_B1 = shuf_A2 + k3;  // .3..
  const auto shuf_B2 = shuf_A0 + k2;  // 3..2
  const auto B0 = TableLookupBytesOr0(v0, shuf_B0);
  const auto B1 = TableLookupBytesOr0(v1, shuf_B1);
  const auto B2 = TableLookupBytesOr0(v2, shuf_B2);
  const VFromD<decltype(d_full)> B = BitCast(d_full, B0 | B1 | B2);
  StoreU(VFromD<D>{B.raw}, dh, unaligned + MaxLanes(d_full));
}

// 64-bit vector, 32-bit lanes
template <class D, HWY_IF_T_SIZE_D(D, 4), HWY_IF_LANES_D(D, 2)>
HWY_API void StoreInterleaved3(VFromD<D> v0, VFromD<D> v1, VFromD<D> v2, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  // (same code as 128-bit vector, 64-bit lanes)
  const VFromD<D> v10_v00 = InterleaveLower(d, v0, v1);
  const VFromD<D> v01_v20 = OddEven(v0, v2);
  const VFromD<D> v21_v11 = InterleaveUpper(d, v1, v2);
  constexpr size_t kN = MaxLanes(d);
  StoreU(v10_v00, d, unaligned + 0 * kN);
  StoreU(v01_v20, d, unaligned + 1 * kN);
  StoreU(v21_v11, d, unaligned + 2 * kN);
}

// 64-bit lanes are handled by the N=1 case below.

// <= 32-bit vector, 8-bit lanes
template <class D, HWY_IF_T_SIZE_D(D, 1), HWY_IF_V_SIZE_LE_D(D, 4),
          HWY_IF_LANES_GT_D(D, 1)>
HWY_API void StoreInterleaved3(VFromD<D> part0, VFromD<D> part1,
                               VFromD<D> part2, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  // Use full vectors for the shuffles and result.
  const Full128<uint8_t> du;
  const Full128<TFromD<D>> d_full;

  const VFromD<decltype(d_full)> v0{part0.raw};
  const VFromD<decltype(d_full)> v1{part1.raw};
  const VFromD<decltype(d_full)> v2{part2.raw};

  // Interleave (v0,v1,v2). We're expanding v0 lanes to their place, with 0x80
  // so lanes to be filled from other vectors are 0 to enable blending by ORing
  // together.
  alignas(16) static constexpr uint8_t tbl_v0[16] = {
      0,    0x80, 0x80, 1,    0x80, 0x80, 2,    0x80,
      0x80, 3,    0x80, 0x80, 0x80, 0x80, 0x80, 0x80};
  // The interleaved vector will be named A; temporaries with suffix
  // 0..2 indicate which input vector's lanes they hold.
  const auto shuf_A0 = Load(du, tbl_v0);
  const auto shuf_A1 = CombineShiftRightBytes<15>(du, shuf_A0, shuf_A0);
  const auto shuf_A2 = CombineShiftRightBytes<14>(du, shuf_A0, shuf_A0);
  const auto A0 = TableLookupBytesOr0(v0, shuf_A0);  // ......3..2..1..0
  const auto A1 = TableLookupBytesOr0(v1, shuf_A1);  // .....3..2..1..0.
  const auto A2 = TableLookupBytesOr0(v2, shuf_A2);  // ....3..2..1..0..
  const VFromD<decltype(d_full)> A = BitCast(d_full, A0 | A1 | A2);
  alignas(16) TFromD<D> buf[MaxLanes(d_full)];
  StoreU(A, d_full, buf);
  CopyBytes<d.MaxBytes() * 3>(buf, unaligned);
}

// 32-bit vector, 16-bit lanes
template <class D, HWY_IF_T_SIZE_D(D, 2), HWY_IF_LANES_D(D, 2)>
HWY_API void StoreInterleaved3(VFromD<D> part0, VFromD<D> part1,
                               VFromD<D> part2, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  // Use full vectors for the shuffles and result.
  const Full128<uint8_t> du8;
  const Full128<TFromD<D>> d_full;

  const VFromD<decltype(d_full)> v0{part0.raw};
  const VFromD<decltype(d_full)> v1{part1.raw};
  const VFromD<decltype(d_full)> v2{part2.raw};

  // Interleave (v0,v1,v2). We're expanding v0 lanes to their place, with 0x80
  // so lanes to be filled from other vectors are 0 to enable blending by ORing
  // together.
  alignas(16) static constexpr uint8_t tbl_v2[16] = {
      0x80, 0x80, 0x80, 0x80, 0,    1,    0x80, 0x80,
      0x80, 0x80, 2,    3,    0x80, 0x80, 0x80, 0x80};
  // The interleaved vector will be named A; temporaries with suffix
  // 0..2 indicate which input vector's lanes they hold.
  const auto shuf_A2 =  // ..1..0..
      Load(du8, tbl_v2);
  const auto shuf_A1 =  // ...1..0.
      CombineShiftRightBytes<2>(du8, shuf_A2, shuf_A2);
  const auto shuf_A0 =  // ....1..0
      CombineShiftRightBytes<4>(du8, shuf_A2, shuf_A2);
  const auto A0 = TableLookupBytesOr0(v0, shuf_A0);  // ..1..0
  const auto A1 = TableLookupBytesOr0(v1, shuf_A1);  // .1..0.
  const auto A2 = TableLookupBytesOr0(v2, shuf_A2);  // 1..0..
  const auto A = BitCast(d_full, A0 | A1 | A2);
  alignas(16) TFromD<D> buf[MaxLanes(d_full)];
  StoreU(A, d_full, buf);
  CopyBytes<d.MaxBytes() * 3>(buf, unaligned);
}

// Single-element vector, any lane size: just store directly
template <class D, HWY_IF_LANES_D(D, 1)>
HWY_API void StoreInterleaved3(VFromD<D> v0, VFromD<D> v1, VFromD<D> v2, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  StoreU(v0, d, unaligned + 0);
  StoreU(v1, d, unaligned + 1);
  StoreU(v2, d, unaligned + 2);
}

// ------------------------------ StoreInterleaved4

namespace detail {

// Default for <= 128-bit vectors; x86_256 and x86_512 have their own overload.
template <class D, HWY_IF_V_SIZE_LE_D(D, 16)>
HWY_INLINE void StoreTransposedBlocks4(VFromD<D> vA, VFromD<D> vB, VFromD<D> vC,
                                       VFromD<D> vD, D d,
                                       TFromD<D>* HWY_RESTRICT unaligned) {
  constexpr size_t kN = MaxLanes(d);
  StoreU(vA, d, unaligned + 0 * kN);
  StoreU(vB, d, unaligned + 1 * kN);
  StoreU(vC, d, unaligned + 2 * kN);
  StoreU(vD, d, unaligned + 3 * kN);
}

}  // namespace detail

// >= 128-bit vector, 8..32-bit lanes
template <class D, HWY_IF_NOT_T_SIZE_D(D, 8), HWY_IF_V_SIZE_GT_D(D, 8)>
HWY_API void StoreInterleaved4(VFromD<D> v0, VFromD<D> v1, VFromD<D> v2,
                               VFromD<D> v3, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  const RepartitionToWide<decltype(d)> dw;
  const auto v10L = ZipLower(dw, v0, v1);  // .. v1[0] v0[0]
  const auto v32L = ZipLower(dw, v2, v3);
  const auto v10U = ZipUpper(dw, v0, v1);
  const auto v32U = ZipUpper(dw, v2, v3);
  // The interleaved vectors are vA, vB, vC, vD.
  const VFromD<D> vA = BitCast(d, InterleaveLower(dw, v10L, v32L));  // 3210
  const VFromD<D> vB = BitCast(d, InterleaveUpper(dw, v10L, v32L));
  const VFromD<D> vC = BitCast(d, InterleaveLower(dw, v10U, v32U));
  const VFromD<D> vD = BitCast(d, InterleaveUpper(dw, v10U, v32U));
  detail::StoreTransposedBlocks4(vA, vB, vC, vD, d, unaligned);
}

// >= 128-bit vector, 64-bit lanes
template <class D, HWY_IF_T_SIZE_D(D, 8), HWY_IF_V_SIZE_GT_D(D, 8)>
HWY_API void StoreInterleaved4(VFromD<D> v0, VFromD<D> v1, VFromD<D> v2,
                               VFromD<D> v3, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  // The interleaved vectors are vA, vB, vC, vD.
  const VFromD<D> vA = InterleaveLower(d, v0, v1);  // v1[0] v0[0]
  const VFromD<D> vB = InterleaveLower(d, v2, v3);
  const VFromD<D> vC = InterleaveUpper(d, v0, v1);
  const VFromD<D> vD = InterleaveUpper(d, v2, v3);
  detail::StoreTransposedBlocks4(vA, vB, vC, vD, d, unaligned);
}

// 64-bit vector, 8..32-bit lanes
template <class D, HWY_IF_NOT_T_SIZE_D(D, 8), HWY_IF_V_SIZE_D(D, 8)>
HWY_API void StoreInterleaved4(VFromD<D> part0, VFromD<D> part1,
                               VFromD<D> part2, VFromD<D> part3, D /* tag */,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  // Use full vectors to reduce the number of stores.
  const Full128<TFromD<D>> d_full;
  const RepartitionToWide<decltype(d_full)> dw;
  const VFromD<decltype(d_full)> v0{part0.raw};
  const VFromD<decltype(d_full)> v1{part1.raw};
  const VFromD<decltype(d_full)> v2{part2.raw};
  const VFromD<decltype(d_full)> v3{part3.raw};
  const auto v10 = ZipLower(dw, v0, v1);  // v1[0] v0[0]
  const auto v32 = ZipLower(dw, v2, v3);
  const auto A = BitCast(d_full, InterleaveLower(dw, v10, v32));
  const auto B = BitCast(d_full, InterleaveUpper(dw, v10, v32));
  StoreU(A, d_full, unaligned);
  StoreU(B, d_full, unaligned + MaxLanes(d_full));
}

// 64-bit vector, 64-bit lane
template <class D, HWY_IF_T_SIZE_D(D, 8), HWY_IF_LANES_D(D, 1)>
HWY_API void StoreInterleaved4(VFromD<D> part0, VFromD<D> part1,
                               VFromD<D> part2, VFromD<D> part3, D /* tag */,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  // Use full vectors to reduce the number of stores.
  const Full128<TFromD<D>> d_full;
  const VFromD<decltype(d_full)> v0{part0.raw};
  const VFromD<decltype(d_full)> v1{part1.raw};
  const VFromD<decltype(d_full)> v2{part2.raw};
  const VFromD<decltype(d_full)> v3{part3.raw};
  const auto A = InterleaveLower(d_full, v0, v1);  // v1[0] v0[0]
  const auto B = InterleaveLower(d_full, v2, v3);
  StoreU(A, d_full, unaligned);
  StoreU(B, d_full, unaligned + MaxLanes(d_full));
}

// <= 32-bit vectors
template <class D, HWY_IF_V_SIZE_LE_D(D, 4)>
HWY_API void StoreInterleaved4(VFromD<D> part0, VFromD<D> part1,
                               VFromD<D> part2, VFromD<D> part3, D d,
                               TFromD<D>* HWY_RESTRICT unaligned) {
  // Use full vectors to reduce the number of stores.
  const Full128<TFromD<D>> d_full;
  const RepartitionToWide<decltype(d_full)> dw;
  const VFromD<decltype(d_full)> v0{part0.raw};
  const VFromD<decltype(d_full)> v1{part1.raw};
  const VFromD<decltype(d_full)> v2{part2.raw};
  const VFromD<decltype(d_full)> v3{part3.raw};
  const auto v10 = ZipLower(dw, v0, v1);  // .. v1[0] v0[0]
  const auto v32 = ZipLower(dw, v2, v3);
  const auto v3210 = BitCast(d_full, InterleaveLower(dw, v10, v32));
  alignas(16) TFromD<D> buf[MaxLanes(d_full)];
  StoreU(v3210, d_full, buf);
  CopyBytes<d.MaxBytes() * 4>(buf, unaligned);
}

#endif  // HWY_NATIVE_LOAD_STORE_INTERLEAVED

// ------------------------------ LoadN
#if (defined(HWY_NATIVE_LOAD_N) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_LOAD_N
#undef HWY_NATIVE_LOAD_N
#else
#define HWY_NATIVE_LOAD_N
#endif

#if HWY_MEM_OPS_MIGHT_FAULT && !HWY_HAVE_SCALABLE
namespace detail {

template <class DTo, class DFrom>
HWY_INLINE VFromD<DTo> LoadNResizeBitCast(DTo d_to, DFrom d_from,
                                          VFromD<DFrom> v) {
#if HWY_TARGET <= HWY_SSE2
  // On SSE2/SSSE3/SSE4, the LoadU operation will zero out any lanes of v.raw
  // past the first (lowest-index) Lanes(d_from) lanes of v.raw if
  // sizeof(decltype(v.raw)) > d_from.MaxBytes() is true
  (void)d_from;
  return ResizeBitCast(d_to, v);
#else
  // On other targets such as PPC/NEON, the contents of any lanes past the first
  // (lowest-index) Lanes(d_from) lanes of v.raw might be non-zero if
  // sizeof(decltype(v.raw)) > d_from.MaxBytes() is true.
  return ZeroExtendResizeBitCast(d_to, d_from, v);
#endif
}

}  // namespace detail

template <class D, HWY_IF_V_SIZE_LE_D(D, 16), HWY_IF_LANES_D(D, 1),
          typename T = TFromD<D>>
HWY_API VFromD<D> LoadN(D d, const T* HWY_RESTRICT p,
                        size_t max_lanes_to_load) {
  return (max_lanes_to_load > 0) ? LoadU(d, p) : Zero(d);
}

template <class D, HWY_IF_V_SIZE_LE_D(D, 16), HWY_IF_LANES_D(D, 2),
          typename T = TFromD<D>>
HWY_API VFromD<D> LoadN(D d, const T* HWY_RESTRICT p,
                        size_t max_lanes_to_load) {
  const FixedTag<TFromD<D>, 1> d1;

  if (max_lanes_to_load >= 2) {
    return LoadU(d, p);
  } else {
    return (max_lanes_to_load == 1)
               ? detail::LoadNResizeBitCast(d, d1, LoadU(d1, p))
               : Zero(d);
  }
}

template <class D, HWY_IF_V_SIZE_LE_D(D, 16), HWY_IF_LANES_D(D, 4),
          typename T = TFromD<D>>
HWY_API VFromD<D> LoadN(D d, const T* HWY_RESTRICT p,
                        size_t max_lanes_to_load) {
  const FixedTag<TFromD<D>, 2> d2;
  const Half<decltype(d2)> d1;

  if (max_lanes_to_load <= 1)
    return (max_lanes_to_load == 1)
               ? detail::LoadNResizeBitCast(d, d1, LoadU(d1, p))
               : Zero(d);
  else if (max_lanes_to_load > 3)
    return LoadU(d, p);

  const auto v_lo = LoadU(d2, p);
  if (max_lanes_to_load == 3) {
    return Combine(d, detail::LoadNResizeBitCast(d2, d1, LoadU(d1, p + 2)),
                   v_lo);
  } else {
    return detail::LoadNResizeBitCast(d, d2, v_lo);
  }
}

template <class D, HWY_IF_V_SIZE_LE_D(D, 16), HWY_IF_LANES_D(D, 8),
          typename T = TFromD<D>>
HWY_API VFromD<D> LoadN(D d, const T* HWY_RESTRICT p,
                        size_t max_lanes_to_load) {
  const FixedTag<TFromD<D>, 4> d4;
  const Half<decltype(d4)> d2;
  const Half<decltype(d2)> d1;

  if (max_lanes_to_load <= 1)
    return (max_lanes_to_load == 1)
               ? detail::LoadNResizeBitCast(d, d1, LoadU(d1, p))
               : Zero(d);
  else if (max_lanes_to_load >= 8)
    return LoadU(d, p);

  const size_t leading_len = max_lanes_to_load & 4;
  VFromD<decltype(d4)> v_trailing = Zero(d4);

  if ((max_lanes_to_load & 2) != 0) {
    const auto v_trailing_lo2 = LoadU(d2, p + leading_len);
    if ((max_lanes_to_load & 1) != 0) {
      v_trailing = Combine(
          d4,
          detail::LoadNResizeBitCast(d2, d1, LoadU(d1, p + leading_len + 2)),
          v_trailing_lo2);
    } else {
      v_trailing = detail::LoadNResizeBitCast(d4, d2, v_trailing_lo2);
    }
  } else if ((max_lanes_to_load & 1) != 0) {
    v_trailing = detail::LoadNResizeBitCast(d4, d1, LoadU(d1, p + leading_len));
  }

  if (leading_len != 0) {
    return Combine(d, v_trailing, LoadU(d4, p));
  } else {
    return detail::LoadNResizeBitCast(d, d4, v_trailing);
  }
}

template <class D, HWY_IF_V_SIZE_LE_D(D, 16), HWY_IF_LANES_D(D, 16),
          typename T = TFromD<D>>
HWY_API VFromD<D> LoadN(D d, const T* HWY_RESTRICT p,
                        size_t max_lanes_to_load) {
  const FixedTag<TFromD<D>, 8> d8;
  const Half<decltype(d8)> d4;
  const Half<decltype(d4)> d2;
  const Half<decltype(d2)> d1;

  if (max_lanes_to_load <= 1)
    return (max_lanes_to_load == 1)
               ? detail::LoadNResizeBitCast(d, d1, LoadU(d1, p))
               : Zero(d);
  else if (max_lanes_to_load >= 16)
    return LoadU(d, p);

  const size_t leading_len = max_lanes_to_load & 12;
  VFromD<decltype(d4)> v_trailing = Zero(d4);

  if ((max_lanes_to_load & 2) != 0) {
    const auto v_trailing_lo2 = LoadU(d2, p + leading_len);
    if ((max_lanes_to_load & 1) != 0) {
      v_trailing = Combine(
          d4,
          detail::LoadNResizeBitCast(d2, d1, LoadU(d1, p + leading_len + 2)),
          v_trailing_lo2);
    } else {
      v_trailing = detail::LoadNResizeBitCast(d4, d2, v_trailing_lo2);
    }
  } else if ((max_lanes_to_load & 1) != 0) {
    v_trailing = detail::LoadNResizeBitCast(d4, d1, LoadU(d1, p + leading_len));
  }

  if (leading_len != 0) {
    if (leading_len >= 8) {
      const auto v_hi7 = ((leading_len & 4) != 0)
                             ? Combine(d8, v_trailing, LoadU(d4, p + 8))
                             : detail::LoadNResizeBitCast(d8, d4, v_trailing);
      return Combine(d, v_hi7, LoadU(d8, p));
    } else {
      return detail::LoadNResizeBitCast(d, d8,
                                        Combine(d8, v_trailing, LoadU(d4, p)));
    }
  } else {
    return detail::LoadNResizeBitCast(d, d4, v_trailing);
  }
}

#if HWY_MAX_BYTES >= 32
template <class D, HWY_IF_V_SIZE_GT_D(D, 16), typename T = TFromD<D>>
HWY_API VFromD<D> LoadN(D d, const T* HWY_RESTRICT p,
                        size_t max_lanes_to_load) {
  const size_t N = Lanes(d);
  if (max_lanes_to_load >= N) {
    return LoadU(d, p);
  }

  const Half<decltype(d)> dh;
  const size_t half_N = Lanes(dh);
  if (max_lanes_to_load <= half_N) {
    return ZeroExtendVector(d, LoadN(dh, p, max_lanes_to_load));
  } else {
    const auto v_lo = LoadU(dh, p);
    const auto v_hi = LoadN(dh, p + half_N, max_lanes_to_load - half_N);
    return Combine(d, v_hi, v_lo);
  }
}
#endif  // HWY_MAX_BYTES >= 32
#else   // !HWY_MEM_OPS_MIGHT_FAULT || HWY_HAVE_SCALABLE
template <class D, typename T = TFromD<D>>
HWY_API VFromD<D> LoadN(D d, const T* HWY_RESTRICT p,
                        size_t max_lanes_to_load) {
#if HWY_MEM_OPS_MIGHT_FAULT
  if (max_lanes_to_load <= 0) return Zero(d);
#endif

  const size_t N = Lanes(d);
  return MaskedLoad(FirstN(d, HWY_MIN(max_lanes_to_load, N)), d, p);
}
#endif  // HWY_MEM_OPS_MIGHT_FAULT && !HWY_HAVE_SCALABLE

#endif

// ------------------------------ StoreN
#if (defined(HWY_NATIVE_STORE_N) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_STORE_N
#undef HWY_NATIVE_STORE_N
#else
#define HWY_NATIVE_STORE_N
#endif

#if HWY_MEM_OPS_MIGHT_FAULT && !HWY_HAVE_SCALABLE
namespace detail {

template <class DH, HWY_IF_V_SIZE_LE_D(DH, 4)>
HWY_INLINE VFromD<DH> StoreNGetUpperHalf(DH dh, VFromD<Twice<DH>> v) {
  constexpr size_t kMinShrVectBytes =
      (HWY_TARGET == HWY_NEON || HWY_TARGET == HWY_NEON_WITHOUT_AES) ? 8 : 16;
  const FixedTag<uint8_t, kMinShrVectBytes> d_shift;
  return ResizeBitCast(
      dh, ShiftRightBytes<dh.MaxBytes()>(d_shift, ResizeBitCast(d_shift, v)));
}

template <class DH, HWY_IF_V_SIZE_GT_D(DH, 4)>
HWY_INLINE VFromD<DH> StoreNGetUpperHalf(DH dh, VFromD<Twice<DH>> v) {
  return UpperHalf(dh, v);
}

}  // namespace detail

template <class D, HWY_IF_V_SIZE_LE_D(D, 16), HWY_IF_LANES_D(D, 1),
          typename T = TFromD<D>>
HWY_API void StoreN(VFromD<D> v, D d, T* HWY_RESTRICT p,
                    size_t max_lanes_to_store) {
  if (max_lanes_to_store > 0) {
    StoreU(v, d, p);
  }
}

template <class D, HWY_IF_V_SIZE_LE_D(D, 16), HWY_IF_LANES_D(D, 2),
          typename T = TFromD<D>>
HWY_API void StoreN(VFromD<D> v, D d, T* HWY_RESTRICT p,
                    size_t max_lanes_to_store) {
  if (max_lanes_to_store > 1) {
    StoreU(v, d, p);
  } else if (max_lanes_to_store == 1) {
    const FixedTag<TFromD<D>, 1> d1;
    StoreU(LowerHalf(d1, v), d1, p);
  }
}

template <class D, HWY_IF_V_SIZE_LE_D(D, 16), HWY_IF_LANES_D(D, 4),
          typename T = TFromD<D>>
HWY_API void StoreN(VFromD<D> v, D d, T* HWY_RESTRICT p,
                    size_t max_lanes_to_store) {
  const FixedTag<TFromD<D>, 2> d2;
  const Half<decltype(d2)> d1;

  if (max_lanes_to_store > 1) {
    if (max_lanes_to_store >= 4) {
      StoreU(v, d, p);
    } else {
      StoreU(ResizeBitCast(d2, v), d2, p);
      if (max_lanes_to_store == 3) {
        StoreU(ResizeBitCast(d1, detail::StoreNGetUpperHalf(d2, v)), d1, p + 2);
      }
    }
  } else if (max_lanes_to_store == 1) {
    StoreU(ResizeBitCast(d1, v), d1, p);
  }
}

template <class D, HWY_IF_V_SIZE_LE_D(D, 16), HWY_IF_LANES_D(D, 8),
          typename T = TFromD<D>>
HWY_API void StoreN(VFromD<D> v, D d, T* HWY_RESTRICT p,
                    size_t max_lanes_to_store) {
  const FixedTag<TFromD<D>, 4> d4;
  const Half<decltype(d4)> d2;
  const Half<decltype(d2)> d1;

  if (max_lanes_to_store <= 1) {
    if (max_lanes_to_store == 1) {
      StoreU(ResizeBitCast(d1, v), d1, p);
    }
  } else if (max_lanes_to_store >= 8) {
    StoreU(v, d, p);
  } else if (max_lanes_to_store >= 4) {
    StoreU(LowerHalf(d4, v), d4, p);
    StoreN(detail::StoreNGetUpperHalf(d4, v), d4, p + 4,
           max_lanes_to_store - 4);
  } else {
    StoreN(LowerHalf(d4, v), d4, p, max_lanes_to_store);
  }
}

template <class D, HWY_IF_V_SIZE_LE_D(D, 16), HWY_IF_LANES_D(D, 16),
          typename T = TFromD<D>>
HWY_API void StoreN(VFromD<D> v, D d, T* HWY_RESTRICT p,
                    size_t max_lanes_to_store) {
  const FixedTag<TFromD<D>, 8> d8;
  const Half<decltype(d8)> d4;
  const Half<decltype(d4)> d2;
  const Half<decltype(d2)> d1;

  if (max_lanes_to_store <= 1) {
    if (max_lanes_to_store == 1) {
      StoreU(ResizeBitCast(d1, v), d1, p);
    }
  } else if (max_lanes_to_store >= 16) {
    StoreU(v, d, p);
  } else if (max_lanes_to_store >= 8) {
    StoreU(LowerHalf(d8, v), d8, p);
    StoreN(detail::StoreNGetUpperHalf(d8, v), d8, p + 8,
           max_lanes_to_store - 8);
  } else {
    StoreN(LowerHalf(d8, v), d8, p, max_lanes_to_store);
  }
}

#if HWY_MAX_BYTES >= 32
template <class D, HWY_IF_V_SIZE_GT_D(D, 16), typename T = TFromD<D>>
HWY_API void StoreN(VFromD<D> v, D d, T* HWY_RESTRICT p,
                    size_t max_lanes_to_store) {
  const size_t N = Lanes(d);
  if (max_lanes_to_store >= N) {
    StoreU(v, d, p);
    return;
  }

  const Half<decltype(d)> dh;
  const size_t half_N = Lanes(dh);
  if (max_lanes_to_store <= half_N) {
    StoreN(LowerHalf(dh, v), dh, p, max_lanes_to_store);
  } else {
    StoreU(LowerHalf(dh, v), dh, p);
    StoreN(UpperHalf(dh, v), dh, p + half_N, max_lanes_to_store - half_N);
  }
}
#endif  // HWY_MAX_BYTES >= 32

#else  // !HWY_MEM_OPS_MIGHT_FAULT || HWY_HAVE_SCALABLE
template <class D, typename T = TFromD<D>>
HWY_API void StoreN(VFromD<D> v, D d, T* HWY_RESTRICT p,
                    size_t max_lanes_to_store) {
  const size_t N = Lanes(d);
  const size_t clamped_max_lanes_to_store = HWY_MIN(max_lanes_to_store, N);
#if HWY_MEM_OPS_MIGHT_FAULT
  if (clamped_max_lanes_to_store == 0) return;
#endif

  BlendedStore(v, FirstN(d, clamped_max_lanes_to_store), d, p);

#if HWY_MEM_OPS_MIGHT_FAULT
  detail::MaybeUnpoison(p, clamped_max_lanes_to_store);
#endif
}
#endif  // HWY_MEM_OPS_MIGHT_FAULT && !HWY_HAVE_SCALABLE

#endif  // (defined(HWY_NATIVE_STORE_N) == defined(HWY_TARGET_TOGGLE))

// ------------------------------ Scatter

#if (defined(HWY_NATIVE_SCATTER) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_SCATTER
#undef HWY_NATIVE_SCATTER
#else
#define HWY_NATIVE_SCATTER
#endif

template <class D, typename T = TFromD<D>>
HWY_API void ScatterOffset(VFromD<D> v, D d, T* HWY_RESTRICT base,
                           VFromD<RebindToSigned<D>> offset) {
  const RebindToSigned<decltype(d)> di;
  using TI = TFromD<decltype(di)>;
  static_assert(sizeof(T) == sizeof(TI), "Index/lane size must match");

  HWY_ALIGN T lanes[MaxLanes(d)];
  Store(v, d, lanes);

  HWY_ALIGN TI offset_lanes[MaxLanes(d)];
  Store(offset, di, offset_lanes);

  uint8_t* base_bytes = reinterpret_cast<uint8_t*>(base);
  for (size_t i = 0; i < MaxLanes(d); ++i) {
    CopyBytes<sizeof(T)>(&lanes[i], base_bytes + offset_lanes[i]);
  }
}

template <class D, typename T = TFromD<D>>
HWY_API void ScatterIndex(VFromD<D> v, D d, T* HWY_RESTRICT base,
                          VFromD<RebindToSigned<D>> index) {
  const RebindToSigned<decltype(d)> di;
  using TI = TFromD<decltype(di)>;
  static_assert(sizeof(T) == sizeof(TI), "Index/lane size must match");

  HWY_ALIGN T lanes[MaxLanes(d)];
  Store(v, d, lanes);

  HWY_ALIGN TI index_lanes[MaxLanes(d)];
  Store(index, di, index_lanes);

  for (size_t i = 0; i < MaxLanes(d); ++i) {
    base[index_lanes[i]] = lanes[i];
  }
}

template <class D, typename T = TFromD<D>>
HWY_API void MaskedScatterIndex(VFromD<D> v, MFromD<D> m, D d,
                                T* HWY_RESTRICT base,
                                VFromD<RebindToSigned<D>> index) {
  const RebindToSigned<decltype(d)> di;
  using TI = TFromD<decltype(di)>;
  static_assert(sizeof(T) == sizeof(TI), "Index/lane size must match");

  HWY_ALIGN T lanes[MaxLanes(d)];
  Store(v, d, lanes);

  HWY_ALIGN TI index_lanes[MaxLanes(d)];
  Store(index, di, index_lanes);

  HWY_ALIGN TI mask_lanes[MaxLanes(di)];
  Store(BitCast(di, VecFromMask(d, m)), di, mask_lanes);

  for (size_t i = 0; i < MaxLanes(d); ++i) {
    if (mask_lanes[i]) base[index_lanes[i]] = lanes[i];
  }
}

#endif  // (defined(HWY_NATIVE_SCATTER) == defined(HWY_TARGET_TOGGLE))

// ------------------------------ Gather

#if (defined(HWY_NATIVE_GATHER) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_GATHER
#undef HWY_NATIVE_GATHER
#else
#define HWY_NATIVE_GATHER
#endif

template <class D, typename T = TFromD<D>>
HWY_API VFromD<D> GatherOffset(D d, const T* HWY_RESTRICT base,
                               VFromD<RebindToSigned<D>> offset) {
  const RebindToSigned<D> di;
  using TI = TFromD<decltype(di)>;
  static_assert(sizeof(T) == sizeof(TI), "Index/lane size must match");

  HWY_ALIGN TI offset_lanes[MaxLanes(d)];
  Store(offset, di, offset_lanes);

  HWY_ALIGN T lanes[MaxLanes(d)];
  const uint8_t* base_bytes = reinterpret_cast<const uint8_t*>(base);
  for (size_t i = 0; i < MaxLanes(d); ++i) {
    CopyBytes<sizeof(T)>(base_bytes + offset_lanes[i], &lanes[i]);
  }
  return Load(d, lanes);
}

template <class D, typename T = TFromD<D>>
HWY_API VFromD<D> GatherIndex(D d, const T* HWY_RESTRICT base,
                              VFromD<RebindToSigned<D>> index) {
  const RebindToSigned<D> di;
  using TI = TFromD<decltype(di)>;
  static_assert(sizeof(T) == sizeof(TI), "Index/lane size must match");

  HWY_ALIGN TI index_lanes[MaxLanes(d)];
  Store(index, di, index_lanes);

  HWY_ALIGN T lanes[MaxLanes(d)];
  for (size_t i = 0; i < MaxLanes(d); ++i) {
    lanes[i] = base[index_lanes[i]];
  }
  return Load(d, lanes);
}

template <class D, typename T = TFromD<D>>
HWY_API VFromD<D> MaskedGatherIndex(MFromD<D> m, D d,
                                    const T* HWY_RESTRICT base,
                                    VFromD<RebindToSigned<D>> index) {
  const RebindToSigned<D> di;
  using TI = TFromD<decltype(di)>;
  static_assert(sizeof(T) == sizeof(TI), "Index/lane size must match");

  HWY_ALIGN TI index_lanes[MaxLanes(di)];
  Store(index, di, index_lanes);

  HWY_ALIGN TI mask_lanes[MaxLanes(di)];
  Store(BitCast(di, VecFromMask(d, m)), di, mask_lanes);

  HWY_ALIGN T lanes[MaxLanes(d)];
  for (size_t i = 0; i < MaxLanes(d); ++i) {
    lanes[i] = mask_lanes[i] ? base[index_lanes[i]] : T{0};
  }
  return Load(d, lanes);
}

#endif  // (defined(HWY_NATIVE_GATHER) == defined(HWY_TARGET_TOGGLE))

// ------------------------------ Integer AbsDiff and SumsOf8AbsDiff

#if (defined(HWY_NATIVE_INTEGER_ABS_DIFF) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_INTEGER_ABS_DIFF
#undef HWY_NATIVE_INTEGER_ABS_DIFF
#else
#define HWY_NATIVE_INTEGER_ABS_DIFF
#endif

template <class V, HWY_IF_NOT_FLOAT_NOR_SPECIAL_V(V)>
HWY_API V AbsDiff(V a, V b) {
  return Sub(Max(a, b), Min(a, b));
}

#endif  // HWY_NATIVE_INTEGER_ABS_DIFF

#if (defined(HWY_NATIVE_SUMS_OF_8_ABS_DIFF) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_SUMS_OF_8_ABS_DIFF
#undef HWY_NATIVE_SUMS_OF_8_ABS_DIFF
#else
#define HWY_NATIVE_SUMS_OF_8_ABS_DIFF
#endif

template <class V, HWY_IF_U8_D(DFromV<V>),
          HWY_IF_V_SIZE_GT_D(DFromV<V>, (HWY_TARGET == HWY_SCALAR ? 0 : 4))>
HWY_API Vec<Repartition<uint64_t, DFromV<V>>> SumsOf8AbsDiff(V a, V b) {
  return SumsOf8(AbsDiff(a, b));
}

#endif  // HWY_NATIVE_SUMS_OF_8_ABS_DIFF

// ------------------------------ SaturatedAdd/SaturatedSub for UI32/UI64

#if (defined(HWY_NATIVE_I32_SATURATED_ADDSUB) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_I32_SATURATED_ADDSUB
#undef HWY_NATIVE_I32_SATURATED_ADDSUB
#else
#define HWY_NATIVE_I32_SATURATED_ADDSUB
#endif

template <class V, HWY_IF_I32_D(DFromV<V>)>
HWY_API V SaturatedAdd(V a, V b) {
  const DFromV<decltype(a)> d;
  const auto sum = Add(a, b);
  const auto overflow_mask = AndNot(Xor(a, b), Xor(a, sum));
  const auto overflow_result =
      Xor(BroadcastSignBit(a), Set(d, LimitsMax<int32_t>()));
  return IfNegativeThenElse(overflow_mask, overflow_result, sum);
}

template <class V, HWY_IF_I32_D(DFromV<V>)>
HWY_API V SaturatedSub(V a, V b) {
  const DFromV<decltype(a)> d;
  const auto diff = Sub(a, b);
  const auto overflow_mask = And(Xor(a, b), Xor(a, diff));
  const auto overflow_result =
      Xor(BroadcastSignBit(a), Set(d, LimitsMax<int32_t>()));
  return IfNegativeThenElse(overflow_mask, overflow_result, diff);
}

#endif  // HWY_NATIVE_I32_SATURATED_ADDSUB

#if (defined(HWY_NATIVE_I64_SATURATED_ADDSUB) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_I64_SATURATED_ADDSUB
#undef HWY_NATIVE_I64_SATURATED_ADDSUB
#else
#define HWY_NATIVE_I64_SATURATED_ADDSUB
#endif

template <class V, HWY_IF_I64_D(DFromV<V>)>
HWY_API V SaturatedAdd(V a, V b) {
  const DFromV<decltype(a)> d;
  const auto sum = Add(a, b);
  const auto overflow_mask = AndNot(Xor(a, b), Xor(a, sum));
  const auto overflow_result =
      Xor(BroadcastSignBit(a), Set(d, LimitsMax<int64_t>()));
  return IfNegativeThenElse(overflow_mask, overflow_result, sum);
}

template <class V, HWY_IF_I64_D(DFromV<V>)>
HWY_API V SaturatedSub(V a, V b) {
  const DFromV<decltype(a)> d;
  const auto diff = Sub(a, b);
  const auto overflow_mask = And(Xor(a, b), Xor(a, diff));
  const auto overflow_result =
      Xor(BroadcastSignBit(a), Set(d, LimitsMax<int64_t>()));
  return IfNegativeThenElse(overflow_mask, overflow_result, diff);
}

#endif  // HWY_NATIVE_I64_SATURATED_ADDSUB

#if (defined(HWY_NATIVE_U32_SATURATED_ADDSUB) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_U32_SATURATED_ADDSUB
#undef HWY_NATIVE_U32_SATURATED_ADDSUB
#else
#define HWY_NATIVE_U32_SATURATED_ADDSUB
#endif

template <class V, HWY_IF_U32_D(DFromV<V>)>
HWY_API V SaturatedAdd(V a, V b) {
  return Add(a, Min(b, Not(a)));
}

template <class V, HWY_IF_U32_D(DFromV<V>)>
HWY_API V SaturatedSub(V a, V b) {
  return Sub(a, Min(a, b));
}

#endif  // HWY_NATIVE_U32_SATURATED_ADDSUB

#if (defined(HWY_NATIVE_U64_SATURATED_ADDSUB) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_U64_SATURATED_ADDSUB
#undef HWY_NATIVE_U64_SATURATED_ADDSUB
#else
#define HWY_NATIVE_U64_SATURATED_ADDSUB
#endif

template <class V, HWY_IF_U64_D(DFromV<V>)>
HWY_API V SaturatedAdd(V a, V b) {
  return Add(a, Min(b, Not(a)));
}

template <class V, HWY_IF_U64_D(DFromV<V>)>
HWY_API V SaturatedSub(V a, V b) {
  return Sub(a, Min(a, b));
}

#endif  // HWY_NATIVE_U64_SATURATED_ADDSUB

// ------------------------------ Unsigned to signed demotions

template <class DN, HWY_IF_SIGNED_D(DN), class V, HWY_IF_UNSIGNED_V(V),
          class V2 = VFromD<Rebind<TFromV<V>, DN>>,
          hwy::EnableIf<(sizeof(TFromD<DN>) < sizeof(TFromV<V>))>* = nullptr,
          HWY_IF_LANES_D(DFromV<V>, HWY_MAX_LANES_D(DFromV<V2>))>
HWY_API VFromD<DN> DemoteTo(DN dn, V v) {
  const DFromV<decltype(v)> d;
  const RebindToSigned<decltype(d)> di;
  const RebindToUnsigned<decltype(dn)> dn_u;

  // First, do a signed to signed demotion. This will convert any values
  // that are greater than hwy::HighestValue<MakeSigned<TFromV<V>>>() to a
  // negative value.
  const auto i2i_demote_result = DemoteTo(dn, BitCast(di, v));

  // Second, convert any negative values to hwy::HighestValue<TFromD<DN>>()
  // using an unsigned Min operation.
  const auto max_signed_val = Set(dn, hwy::HighestValue<TFromD<DN>>());

  return BitCast(
      dn, Min(BitCast(dn_u, i2i_demote_result), BitCast(dn_u, max_signed_val)));
}

#if HWY_TARGET != HWY_SCALAR || HWY_IDE
template <class DN, HWY_IF_SIGNED_D(DN), class V, HWY_IF_UNSIGNED_V(V),
          class V2 = VFromD<Repartition<TFromV<V>, DN>>,
          HWY_IF_T_SIZE_V(V, sizeof(TFromD<DN>) * 2),
          HWY_IF_LANES_D(DFromV<V>, HWY_MAX_LANES_D(DFromV<V2>))>
HWY_API VFromD<DN> ReorderDemote2To(DN dn, V a, V b) {
  const DFromV<decltype(a)> d;
  const RebindToSigned<decltype(d)> di;
  const RebindToUnsigned<decltype(dn)> dn_u;

  // First, do a signed to signed demotion. This will convert any values
  // that are greater than hwy::HighestValue<MakeSigned<TFromV<V>>>() to a
  // negative value.
  const auto i2i_demote_result =
      ReorderDemote2To(dn, BitCast(di, a), BitCast(di, b));

  // Second, convert any negative values to hwy::HighestValue<TFromD<DN>>()
  // using an unsigned Min operation.
  const auto max_signed_val = Set(dn, hwy::HighestValue<TFromD<DN>>());

  return BitCast(
      dn, Min(BitCast(dn_u, i2i_demote_result), BitCast(dn_u, max_signed_val)));
}
#endif

// ------------------------------ PromoteLowerTo

// There is no codegen advantage for a native version of this. It is provided
// only for convenience.
template <class D, class V>
HWY_API VFromD<D> PromoteLowerTo(D d, V v) {
  // Lanes(d) may differ from Lanes(DFromV<V>()). Use the lane type from V
  // because it cannot be deduced from D (could be either bf16 or f16).
  const Rebind<TFromV<V>, decltype(d)> dh;
  return PromoteTo(d, LowerHalf(dh, v));
}

// ------------------------------ PromoteUpperTo

#if (defined(HWY_NATIVE_PROMOTE_UPPER_TO) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_PROMOTE_UPPER_TO
#undef HWY_NATIVE_PROMOTE_UPPER_TO
#else
#define HWY_NATIVE_PROMOTE_UPPER_TO
#endif

// This requires UpperHalf.
#if HWY_TARGET != HWY_SCALAR || HWY_IDE

template <class D, class V>
HWY_API VFromD<D> PromoteUpperTo(D d, V v) {
  // Lanes(d) may differ from Lanes(DFromV<V>()). Use the lane type from V
  // because it cannot be deduced from D (could be either bf16 or f16).
  const Rebind<TFromV<V>, decltype(d)> dh;
  return PromoteTo(d, UpperHalf(dh, v));
}

#endif  // HWY_TARGET != HWY_SCALAR
#endif  // HWY_NATIVE_PROMOTE_UPPER_TO

// ------------------------------ float16_t <-> float

#if (defined(HWY_NATIVE_F16C) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_F16C
#undef HWY_NATIVE_F16C
#else
#define HWY_NATIVE_F16C
#endif

template <class D, HWY_IF_F32_D(D)>
HWY_API VFromD<D> PromoteTo(D df32, VFromD<Rebind<float16_t, D>> v) {
  const RebindToSigned<decltype(df32)> di32;
  const RebindToUnsigned<decltype(df32)> du32;
  const Rebind<uint16_t, decltype(df32)> du16;
  using VU32 = VFromD<decltype(du32)>;

  const VU32 bits16 = PromoteTo(du32, BitCast(du16, v));
  const VU32 sign = ShiftRight<15>(bits16);
  const VU32 biased_exp = And(ShiftRight<10>(bits16), Set(du32, 0x1F));
  const VU32 mantissa = And(bits16, Set(du32, 0x3FF));
  const VU32 subnormal =
      BitCast(du32, Mul(ConvertTo(df32, BitCast(di32, mantissa)),
                        Set(df32, 1.0f / 16384 / 1024)));

  const VU32 biased_exp32 = Add(biased_exp, Set(du32, 127 - 15));
  const VU32 mantissa32 = ShiftLeft<23 - 10>(mantissa);
  const VU32 normal = Or(ShiftLeft<23>(biased_exp32), mantissa32);
  const VU32 bits32 = IfThenElse(Eq(biased_exp, Zero(du32)), subnormal, normal);
  return BitCast(df32, Or(ShiftLeft<31>(sign), bits32));
}

template <class D, HWY_IF_F16_D(D)>
HWY_API VFromD<D> DemoteTo(D df16, VFromD<Rebind<float, D>> v) {
  const RebindToUnsigned<decltype(df16)> du16;
  const Rebind<uint32_t, decltype(df16)> du32;
  const RebindToSigned<decltype(du32)> di32;
  using VU32 = VFromD<decltype(du32)>;
  using VI32 = VFromD<decltype(di32)>;

  const VU32 bits32 = BitCast(du32, v);
  const VU32 sign = ShiftRight<31>(bits32);
  const VU32 biased_exp32 = And(ShiftRight<23>(bits32), Set(du32, 0xFF));
  const VU32 mantissa32 = And(bits32, Set(du32, 0x7FFFFF));

  const VI32 k15 = Set(di32, 15);
  const VI32 exp = Min(Sub(BitCast(di32, biased_exp32), Set(di32, 127)), k15);
  const MFromD<decltype(di32)> is_tiny = Lt(exp, Set(di32, -24));

  const MFromD<decltype(di32)> is_subnormal = Lt(exp, Set(di32, -14));
  const VU32 biased_exp16 =
      BitCast(du32, IfThenZeroElse(is_subnormal, Add(exp, k15)));
  const VU32 sub_exp = BitCast(du32, Sub(Set(di32, -14), exp));  // [1, 11)
  // Clamp shift counts to prevent warnings in emu_128 Shr.
  const VU32 k31 = Set(du32, 31);
  const VU32 shift_m = Min(Add(Set(du32, 13), sub_exp), k31);
  const VU32 shift_1 = Min(Sub(Set(du32, 10), sub_exp), k31);
  const VU32 sub_m = Add(Shl(Set(du32, 1), shift_1), Shr(mantissa32, shift_m));
  const VU32 mantissa16 = IfThenElse(RebindMask(du32, is_subnormal), sub_m,
                                     ShiftRight<13>(mantissa32));  // <1024

  const VU32 sign16 = ShiftLeft<15>(sign);
  const VU32 normal16 = Or3(sign16, ShiftLeft<10>(biased_exp16), mantissa16);
  const VI32 bits16 = IfThenZeroElse(is_tiny, BitCast(di32, normal16));
  return BitCast(df16, DemoteTo(du16, bits16));
}

#endif  // HWY_NATIVE_F16C

// ------------------------------ OrderedTruncate2To

#if HWY_IDE || \
    (defined(HWY_NATIVE_ORDERED_TRUNCATE_2_TO) == defined(HWY_TARGET_TOGGLE))

#ifdef HWY_NATIVE_ORDERED_TRUNCATE_2_TO
#undef HWY_NATIVE_ORDERED_TRUNCATE_2_TO
#else
#define HWY_NATIVE_ORDERED_TRUNCATE_2_TO
#endif

// (Must come after HWY_TARGET_TOGGLE, else we don't reset it for scalar)
#if HWY_TARGET != HWY_SCALAR || HWY_IDE
template <class DN, HWY_IF_UNSIGNED_D(DN), class V, HWY_IF_UNSIGNED_V(V),
          HWY_IF_T_SIZE_V(V, sizeof(TFromD<DN>) * 2),
          HWY_IF_LANES_D(DFromV<VFromD<DN>>, HWY_MAX_LANES_D(DFromV<V>) * 2)>
HWY_API VFromD<DN> OrderedTruncate2To(DN dn, V a, V b) {
  return ConcatEven(dn, BitCast(dn, b), BitCast(dn, a));
}
#endif  // HWY_TARGET != HWY_SCALAR
#endif  // HWY_NATIVE_ORDERED_TRUNCATE_2_TO

// -------------------- LeadingZeroCount, TrailingZeroCount, HighestSetBitIndex

#if (defined(HWY_NATIVE_LEADING_ZERO_COUNT) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_LEADING_ZERO_COUNT
#undef HWY_NATIVE_LEADING_ZERO_COUNT
#else
#define HWY_NATIVE_LEADING_ZERO_COUNT
#endif

namespace detail {

template <class D, HWY_IF_U32_D(D)>
HWY_INLINE VFromD<D> UIntToF32BiasedExp(D d, VFromD<D> v) {
  const RebindToFloat<decltype(d)> df;
#if HWY_TARGET > HWY_AVX3 && HWY_TARGET <= HWY_SSE2
  const RebindToSigned<decltype(d)> di;
  const Repartition<int16_t, decltype(d)> di16;

  // On SSE2/SSSE3/SSE4/AVX2, do an int32_t to float conversion, followed
  // by a unsigned right shift of the uint32_t bit representation of the
  // floating point values by 23, followed by an int16_t Min
  // operation as we are only interested in the biased exponent that would
  // result from a uint32_t to float conversion.

  // An int32_t to float vector conversion is also much more efficient on
  // SSE2/SSSE3/SSE4/AVX2 than an uint32_t vector to float vector conversion
  // as an uint32_t vector to float vector conversion on SSE2/SSSE3/SSE4/AVX2
  // requires multiple instructions whereas an int32_t to float vector
  // conversion can be carried out using a single instruction on
  // SSE2/SSSE3/SSE4/AVX2.

  const auto f32_bits = BitCast(d, ConvertTo(df, BitCast(di, v)));
  return BitCast(d, Min(BitCast(di16, ShiftRight<23>(f32_bits)),
                        BitCast(di16, Set(d, 158))));
#else
  const auto f32_bits = BitCast(d, ConvertTo(df, v));
  return BitCast(d, ShiftRight<23>(f32_bits));
#endif
}

template <class V, HWY_IF_U32_D(DFromV<V>)>
HWY_INLINE V I32RangeU32ToF32BiasedExp(V v) {
  // I32RangeU32ToF32BiasedExp is similar to UIntToF32BiasedExp, but
  // I32RangeU32ToF32BiasedExp assumes that v[i] is between 0 and 2147483647.
  const DFromV<decltype(v)> d;
  const RebindToFloat<decltype(d)> df;
#if HWY_TARGET > HWY_AVX3 && HWY_TARGET <= HWY_SSE2
  const RebindToSigned<decltype(d)> d_src;
#else
  const RebindToUnsigned<decltype(d)> d_src;
#endif
  const auto f32_bits = BitCast(d, ConvertTo(df, BitCast(d_src, v)));
  return ShiftRight<23>(f32_bits);
}

template <class D, HWY_IF_U16_D(D), HWY_IF_LANES_LE_D(D, HWY_MAX_BYTES / 4)>
HWY_INLINE VFromD<D> UIntToF32BiasedExp(D d, VFromD<D> v) {
  const Rebind<uint32_t, decltype(d)> du32;
  const auto f32_biased_exp_as_u32 =
      I32RangeU32ToF32BiasedExp(PromoteTo(du32, v));
  return TruncateTo(d, f32_biased_exp_as_u32);
}

#if HWY_TARGET != HWY_SCALAR
template <class D, HWY_IF_U16_D(D), HWY_IF_LANES_GT_D(D, HWY_MAX_BYTES / 4)>
HWY_INLINE VFromD<D> UIntToF32BiasedExp(D d, VFromD<D> v) {
  const Half<decltype(d)> dh;
  const Rebind<uint32_t, decltype(dh)> du32;

  const auto lo_u32 = PromoteTo(du32, LowerHalf(dh, v));
  const auto hi_u32 = PromoteTo(du32, UpperHalf(dh, v));

  const auto lo_f32_biased_exp_as_u32 = I32RangeU32ToF32BiasedExp(lo_u32);
  const auto hi_f32_biased_exp_as_u32 = I32RangeU32ToF32BiasedExp(hi_u32);
#if HWY_TARGET <= HWY_SSE2
  const RebindToSigned<decltype(du32)> di32;
  const RebindToSigned<decltype(d)> di;
  return BitCast(d,
                 OrderedDemote2To(di, BitCast(di32, lo_f32_biased_exp_as_u32),
                                  BitCast(di32, hi_f32_biased_exp_as_u32)));
#else
  return OrderedTruncate2To(d, lo_f32_biased_exp_as_u32,
                            hi_f32_biased_exp_as_u32);
#endif
}
#endif  // HWY_TARGET != HWY_SCALAR

template <class D, HWY_IF_U8_D(D), HWY_IF_LANES_LE_D(D, HWY_MAX_BYTES / 4)>
HWY_INLINE VFromD<D> UIntToF32BiasedExp(D d, VFromD<D> v) {
  const Rebind<uint32_t, decltype(d)> du32;
  const auto f32_biased_exp_as_u32 =
      I32RangeU32ToF32BiasedExp(PromoteTo(du32, v));
  return U8FromU32(f32_biased_exp_as_u32);
}

#if HWY_TARGET != HWY_SCALAR
template <class D, HWY_IF_U8_D(D), HWY_IF_LANES_GT_D(D, HWY_MAX_BYTES / 4),
          HWY_IF_LANES_LE_D(D, HWY_MAX_BYTES / 2)>
HWY_INLINE VFromD<D> UIntToF32BiasedExp(D d, VFromD<D> v) {
  const Half<decltype(d)> dh;
  const Rebind<uint32_t, decltype(dh)> du32;
  const Repartition<uint16_t, decltype(du32)> du16;

  const auto lo_u32 = PromoteTo(du32, LowerHalf(dh, v));
  const auto hi_u32 = PromoteTo(du32, UpperHalf(dh, v));

  const auto lo_f32_biased_exp_as_u32 = I32RangeU32ToF32BiasedExp(lo_u32);
  const auto hi_f32_biased_exp_as_u32 = I32RangeU32ToF32BiasedExp(hi_u32);

#if HWY_TARGET <= HWY_SSE2
  const RebindToSigned<decltype(du32)> di32;
  const RebindToSigned<decltype(du16)> di16;
  const auto f32_biased_exp_as_i16 =
      OrderedDemote2To(di16, BitCast(di32, lo_f32_biased_exp_as_u32),
                       BitCast(di32, hi_f32_biased_exp_as_u32));
  return DemoteTo(d, f32_biased_exp_as_i16);
#else
  const auto f32_biased_exp_as_u16 = OrderedTruncate2To(
      du16, lo_f32_biased_exp_as_u32, hi_f32_biased_exp_as_u32);
  return TruncateTo(d, f32_biased_exp_as_u16);
#endif
}

template <class D, HWY_IF_U8_D(D), HWY_IF_LANES_GT_D(D, HWY_MAX_BYTES / 2)>
HWY_INLINE VFromD<D> UIntToF32BiasedExp(D d, VFromD<D> v) {
  const Half<decltype(d)> dh;
  const Half<decltype(dh)> dq;
  const Rebind<uint32_t, decltype(dq)> du32;
  const Repartition<uint16_t, decltype(du32)> du16;

  const auto lo_half = LowerHalf(dh, v);
  const auto hi_half = UpperHalf(dh, v);

  const auto u32_q0 = PromoteTo(du32, LowerHalf(dq, lo_half));
  const auto u32_q1 = PromoteTo(du32, UpperHalf(dq, lo_half));
  const auto u32_q2 = PromoteTo(du32, LowerHalf(dq, hi_half));
  const auto u32_q3 = PromoteTo(du32, UpperHalf(dq, hi_half));

  const auto f32_biased_exp_as_u32_q0 = I32RangeU32ToF32BiasedExp(u32_q0);
  const auto f32_biased_exp_as_u32_q1 = I32RangeU32ToF32BiasedExp(u32_q1);
  const auto f32_biased_exp_as_u32_q2 = I32RangeU32ToF32BiasedExp(u32_q2);
  const auto f32_biased_exp_as_u32_q3 = I32RangeU32ToF32BiasedExp(u32_q3);

#if HWY_TARGET <= HWY_SSE2
  const RebindToSigned<decltype(du32)> di32;
  const RebindToSigned<decltype(du16)> di16;

  const auto lo_f32_biased_exp_as_i16 =
      OrderedDemote2To(di16, BitCast(di32, f32_biased_exp_as_u32_q0),
                       BitCast(di32, f32_biased_exp_as_u32_q1));
  const auto hi_f32_biased_exp_as_i16 =
      OrderedDemote2To(di16, BitCast(di32, f32_biased_exp_as_u32_q2),
                       BitCast(di32, f32_biased_exp_as_u32_q3));
  return OrderedDemote2To(d, lo_f32_biased_exp_as_i16,
                          hi_f32_biased_exp_as_i16);
#else
  const auto lo_f32_biased_exp_as_u16 = OrderedTruncate2To(
      du16, f32_biased_exp_as_u32_q0, f32_biased_exp_as_u32_q1);
  const auto hi_f32_biased_exp_as_u16 = OrderedTruncate2To(
      du16, f32_biased_exp_as_u32_q2, f32_biased_exp_as_u32_q3);
  return OrderedTruncate2To(d, lo_f32_biased_exp_as_u16,
                            hi_f32_biased_exp_as_u16);
#endif
}
#endif  // HWY_TARGET != HWY_SCALAR

#if HWY_TARGET == HWY_SCALAR
template <class D>
using F32ExpLzcntMinMaxRepartition = RebindToUnsigned<D>;
#elif HWY_TARGET >= HWY_SSSE3 && HWY_TARGET <= HWY_SSE2
template <class D>
using F32ExpLzcntMinMaxRepartition = Repartition<uint8_t, D>;
#else
template <class D>
using F32ExpLzcntMinMaxRepartition =
    Repartition<UnsignedFromSize<HWY_MIN(sizeof(TFromD<D>), 4)>, D>;
#endif

template <class V>
using F32ExpLzcntMinMaxCmpV = VFromD<F32ExpLzcntMinMaxRepartition<DFromV<V>>>;

template <class V>
HWY_INLINE F32ExpLzcntMinMaxCmpV<V> F32ExpLzcntMinMaxBitCast(V v) {
  const DFromV<decltype(v)> d;
  const F32ExpLzcntMinMaxRepartition<decltype(d)> d2;
  return BitCast(d2, v);
}

template <class D, HWY_IF_U64_D(D)>
HWY_INLINE VFromD<D> UIntToF32BiasedExp(D d, VFromD<D> v) {
#if HWY_TARGET == HWY_SCALAR
  const uint64_t u64_val = GetLane(v);
  const float f32_val = static_cast<float>(u64_val);
  uint32_t f32_bits;
  CopySameSize(&f32_val, &f32_bits);
  return Set(d, static_cast<uint64_t>(f32_bits >> 23));
#else
  const Repartition<uint32_t, decltype(d)> du32;
  const auto f32_biased_exp = UIntToF32BiasedExp(du32, BitCast(du32, v));
  const auto f32_biased_exp_adj =
      IfThenZeroElse(Eq(f32_biased_exp, Zero(du32)),
                     BitCast(du32, Set(d, 0x0000002000000000u)));
  const auto adj_f32_biased_exp = Add(f32_biased_exp, f32_biased_exp_adj);

  return ShiftRight<32>(BitCast(
      d, Max(F32ExpLzcntMinMaxBitCast(adj_f32_biased_exp),
             F32ExpLzcntMinMaxBitCast(Reverse2(du32, adj_f32_biased_exp)))));
#endif
}

template <class V, HWY_IF_UNSIGNED_V(V)>
HWY_INLINE V UIntToF32BiasedExp(V v) {
  const DFromV<decltype(v)> d;
  return UIntToF32BiasedExp(d, v);
}

template <class V, HWY_IF_UNSIGNED_V(V),
          HWY_IF_T_SIZE_ONE_OF_V(V, (1 << 1) | (1 << 2))>
HWY_INLINE V NormalizeForUIntTruncConvToF32(V v) {
  return v;
}

template <class V, HWY_IF_UNSIGNED_V(V),
          HWY_IF_T_SIZE_ONE_OF_V(V, (1 << 4) | (1 << 8))>
HWY_INLINE V NormalizeForUIntTruncConvToF32(V v) {
  // If v[i] >= 16777216 is true, make sure that the bit at
  // HighestSetBitIndex(v[i]) - 24 is zeroed out to ensure that any inexact
  // conversion to single-precision floating point is rounded down.

  // This zeroing-out can be accomplished through the AndNot operation below.
  return AndNot(ShiftRight<24>(v), v);
}

}  // namespace detail

template <class V, HWY_IF_NOT_FLOAT_NOR_SPECIAL_V(V)>
HWY_API V HighestSetBitIndex(V v) {
  const DFromV<decltype(v)> d;
  const RebindToUnsigned<decltype(d)> du;
  using TU = TFromD<decltype(du)>;

  const auto f32_biased_exp = detail::UIntToF32BiasedExp(
      detail::NormalizeForUIntTruncConvToF32(BitCast(du, v)));
  return BitCast(d, Sub(f32_biased_exp, Set(du, TU{127})));
}

template <class V, HWY_IF_NOT_FLOAT_NOR_SPECIAL_V(V)>
HWY_API V LeadingZeroCount(V v) {
  const DFromV<decltype(v)> d;
  const RebindToUnsigned<decltype(d)> du;
  using TU = TFromD<decltype(du)>;

  constexpr TU kNumOfBitsInT{sizeof(TU) * 8};
  const auto f32_biased_exp = detail::UIntToF32BiasedExp(
      detail::NormalizeForUIntTruncConvToF32(BitCast(du, v)));
  const auto lz_count = Sub(Set(du, TU{kNumOfBitsInT + 126}), f32_biased_exp);

  return BitCast(d,
                 Min(detail::F32ExpLzcntMinMaxBitCast(lz_count),
                     detail::F32ExpLzcntMinMaxBitCast(Set(du, kNumOfBitsInT))));
}

template <class V, HWY_IF_NOT_FLOAT_NOR_SPECIAL_V(V)>
HWY_API V TrailingZeroCount(V v) {
  const DFromV<decltype(v)> d;
  const RebindToUnsigned<decltype(d)> du;
  const RebindToSigned<decltype(d)> di;
  using TU = TFromD<decltype(du)>;

  const auto vi = BitCast(di, v);
  const auto lowest_bit = BitCast(du, And(vi, Neg(vi)));

  constexpr TU kNumOfBitsInT{sizeof(TU) * 8};
  const auto f32_biased_exp = detail::UIntToF32BiasedExp(lowest_bit);
  const auto tz_count = Sub(f32_biased_exp, Set(du, TU{127}));

  return BitCast(d,
                 Min(detail::F32ExpLzcntMinMaxBitCast(tz_count),
                     detail::F32ExpLzcntMinMaxBitCast(Set(du, kNumOfBitsInT))));
}
#endif  // HWY_NATIVE_LEADING_ZERO_COUNT

// ------------------------------ AESRound

// Cannot implement on scalar: need at least 16 bytes for TableLookupBytes.
#if HWY_TARGET != HWY_SCALAR || HWY_IDE

// Define for white-box testing, even if native instructions are available.
namespace detail {

// Constant-time: computes inverse in GF(2^4) based on "Accelerating AES with
// Vector Permute Instructions" and the accompanying assembly language
// implementation: https://crypto.stanford.edu/vpaes/vpaes.tgz. See also Botan:
// https://botan.randombit.net/doxygen/aes__vperm_8cpp_source.html .
//
// A brute-force 256 byte table lookup can also be made constant-time, and
// possibly competitive on NEON, but this is more performance-portable
// especially for x86 and large vectors.

template <class V>  // u8
HWY_INLINE V SubBytesMulInverseAndAffineLookup(V state, V affine_tblL,
                                               V affine_tblU) {
  const DFromV<V> du;
  const auto mask = Set(du, uint8_t{0xF});

  // Change polynomial basis to GF(2^4)
  {
    alignas(16) static constexpr uint8_t basisL[16] = {
        0x00, 0x70, 0x2A, 0x5A, 0x98, 0xE8, 0xB2, 0xC2,
        0x08, 0x78, 0x22, 0x52, 0x90, 0xE0, 0xBA, 0xCA};
    alignas(16) static constexpr uint8_t basisU[16] = {
        0x00, 0x4D, 0x7C, 0x31, 0x7D, 0x30, 0x01, 0x4C,
        0x81, 0xCC, 0xFD, 0xB0, 0xFC, 0xB1, 0x80, 0xCD};
    const auto sL = And(state, mask);
    const auto sU = ShiftRight<4>(state);  // byte shift => upper bits are zero
    const auto gf4L = TableLookupBytes(LoadDup128(du, basisL), sL);
    const auto gf4U = TableLookupBytes(LoadDup128(du, basisU), sU);
    state = Xor(gf4L, gf4U);
  }

  // Inversion in GF(2^4). Elements 0 represent "infinity" (division by 0) and
  // cause TableLookupBytesOr0 to return 0.
  alignas(16) static constexpr uint8_t kZetaInv[16] = {
      0x80, 7, 11, 15, 6, 10, 4, 1, 9, 8, 5, 2, 12, 14, 13, 3};
  alignas(16) static constexpr uint8_t kInv[16] = {
      0x80, 1, 8, 13, 15, 6, 5, 14, 2, 12, 11, 10, 9, 3, 7, 4};
  const auto tbl = LoadDup128(du, kInv);
  const auto sL = And(state, mask);      // L=low nibble, U=upper
  const auto sU = ShiftRight<4>(state);  // byte shift => upper bits are zero
  const auto sX = Xor(sU, sL);
  const auto invL = TableLookupBytes(LoadDup128(du, kZetaInv), sL);
  const auto invU = TableLookupBytes(tbl, sU);
  const auto invX = TableLookupBytes(tbl, sX);
  const auto outL = Xor(sX, TableLookupBytesOr0(tbl, Xor(invL, invU)));
  const auto outU = Xor(sU, TableLookupBytesOr0(tbl, Xor(invL, invX)));

  const auto affL = TableLookupBytesOr0(affine_tblL, outL);
  const auto affU = TableLookupBytesOr0(affine_tblU, outU);
  return Xor(affL, affU);
}

template <class V>  // u8
HWY_INLINE V SubBytes(V state) {
  const DFromV<V> du;
  // Linear skew (cannot bake 0x63 bias into the table because out* indices
  // may have the infinity flag set).
  alignas(16) static constexpr uint8_t kAffineL[16] = {
      0x00, 0xC7, 0xBD, 0x6F, 0x17, 0x6D, 0xD2, 0xD0,
      0x78, 0xA8, 0x02, 0xC5, 0x7A, 0xBF, 0xAA, 0x15};
  alignas(16) static constexpr uint8_t kAffineU[16] = {
      0x00, 0x6A, 0xBB, 0x5F, 0xA5, 0x74, 0xE4, 0xCF,
      0xFA, 0x35, 0x2B, 0x41, 0xD1, 0x90, 0x1E, 0x8E};
  return Xor(SubBytesMulInverseAndAffineLookup(state, LoadDup128(du, kAffineL),
                                               LoadDup128(du, kAffineU)),
             Set(du, uint8_t{0x63}));
}

template <class V>  // u8
HWY_INLINE V InvSubBytes(V state) {
  const DFromV<V> du;
  alignas(16) static constexpr uint8_t kGF2P4InvToGF2P8InvL[16]{
      0x00, 0x40, 0xF9, 0x7E, 0x53, 0xEA, 0x87, 0x13,
      0x2D, 0x3E, 0x94, 0xD4, 0xB9, 0x6D, 0xAA, 0xC7};
  alignas(16) static constexpr uint8_t kGF2P4InvToGF2P8InvU[16]{
      0x00, 0x1D, 0x44, 0x93, 0x0F, 0x56, 0xD7, 0x12,
      0x9C, 0x8E, 0xC5, 0xD8, 0x59, 0x81, 0x4B, 0xCA};

  // Apply the inverse affine transformation
  const auto b = Xor(Xor3(Or(ShiftLeft<1>(state), ShiftRight<7>(state)),
                          Or(ShiftLeft<3>(state), ShiftRight<5>(state)),
                          Or(ShiftLeft<6>(state), ShiftRight<2>(state))),
                     Set(du, uint8_t{0x05}));

  // The GF(2^8) multiplicative inverse is computed as follows:
  // - Changing the polynomial basis to GF(2^4)
  // - Computing the GF(2^4) multiplicative inverse
  // - Converting the GF(2^4) multiplicative inverse to the GF(2^8)
  //   multiplicative inverse through table lookups using the
  //   kGF2P4InvToGF2P8InvL and kGF2P4InvToGF2P8InvU tables
  return SubBytesMulInverseAndAffineLookup(
      b, LoadDup128(du, kGF2P4InvToGF2P8InvL),
      LoadDup128(du, kGF2P4InvToGF2P8InvU));
}

}  // namespace detail

#endif  // HWY_TARGET != HWY_SCALAR

// "Include guard": skip if native AES instructions are available.
#if (defined(HWY_NATIVE_AES) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_AES
#undef HWY_NATIVE_AES
#else
#define HWY_NATIVE_AES
#endif

// (Must come after HWY_TARGET_TOGGLE, else we don't reset it for scalar)
#if HWY_TARGET != HWY_SCALAR

namespace detail {

template <class V>  // u8
HWY_API V ShiftRows(const V state) {
  const DFromV<V> du;
  alignas(16) static constexpr uint8_t kShiftRow[16] = {
      0,  5,  10, 15,  // transposed: state is column major
      4,  9,  14, 3,   //
      8,  13, 2,  7,   //
      12, 1,  6,  11};
  const auto shift_row = LoadDup128(du, kShiftRow);
  return TableLookupBytes(state, shift_row);
}

template <class V>  // u8
HWY_API V InvShiftRows(const V state) {
  const DFromV<V> du;
  alignas(16) static constexpr uint8_t kShiftRow[16] = {
      0,  13, 10, 7,   // transposed: state is column major
      4,  1,  14, 11,  //
      8,  5,  2,  15,  //
      12, 9,  6,  3};
  const auto shift_row = LoadDup128(du, kShiftRow);
  return TableLookupBytes(state, shift_row);
}

template <class V>  // u8
HWY_API V GF2P8Mod11BMulBy2(V v) {
  const DFromV<V> du;
  const RebindToSigned<decltype(du)> di;  // can only do signed comparisons
  const auto msb = Lt(BitCast(di, v), Zero(di));
  const auto overflow = BitCast(du, IfThenElseZero(msb, Set(di, int8_t{0x1B})));
  return Xor(Add(v, v), overflow);  // = v*2 in GF(2^8).
}

template <class V>  // u8
HWY_API V MixColumns(const V state) {
  const DFromV<V> du;
  // For each column, the rows are the sum of GF(2^8) matrix multiplication by:
  // 2 3 1 1  // Let s := state*1, d := state*2, t := state*3.
  // 1 2 3 1  // d are on diagonal, no permutation needed.
  // 1 1 2 3  // t1230 indicates column indices of threes for the 4 rows.
  // 3 1 1 2  // We also need to compute s2301 and s3012 (=1230 o 2301).
  alignas(16) static constexpr uint8_t k2301[16] = {
      2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13};
  alignas(16) static constexpr uint8_t k1230[16] = {
      1, 2, 3, 0, 5, 6, 7, 4, 9, 10, 11, 8, 13, 14, 15, 12};
  const auto d = GF2P8Mod11BMulBy2(state);  // = state*2 in GF(2^8).
  const auto s2301 = TableLookupBytes(state, LoadDup128(du, k2301));
  const auto d_s2301 = Xor(d, s2301);
  const auto t_s2301 = Xor(state, d_s2301);  // t(s*3) = XOR-sum {s, d(s*2)}
  const auto t1230_s3012 = TableLookupBytes(t_s2301, LoadDup128(du, k1230));
  return Xor(d_s2301, t1230_s3012);  // XOR-sum of 4 terms
}

template <class V>  // u8
HWY_API V InvMixColumns(const V state) {
  const DFromV<V> du;
  // For each column, the rows are the sum of GF(2^8) matrix multiplication by:
  // 14 11 13  9
  //  9 14 11 13
  // 13  9 14 11
  // 11 13  9 14
  alignas(16) static constexpr uint8_t k2301[16] = {
      2, 3, 0, 1, 6, 7, 4, 5, 10, 11, 8, 9, 14, 15, 12, 13};
  alignas(16) static constexpr uint8_t k1230[16] = {
      1, 2, 3, 0, 5, 6, 7, 4, 9, 10, 11, 8, 13, 14, 15, 12};
  const auto v1230 = LoadDup128(du, k1230);

  const auto sx2 = GF2P8Mod11BMulBy2(state); /* = state*2 in GF(2^8) */
  const auto sx4 = GF2P8Mod11BMulBy2(sx2);   /* = state*4 in GF(2^8) */
  const auto sx8 = GF2P8Mod11BMulBy2(sx4);   /* = state*8 in GF(2^8) */
  const auto sx9 = Xor(sx8, state);          /* = state*9 in GF(2^8) */
  const auto sx11 = Xor(sx9, sx2);           /* = state*11 in GF(2^8) */
  const auto sx13 = Xor(sx9, sx4);           /* = state*13 in GF(2^8) */
  const auto sx14 = Xor3(sx8, sx4, sx2);     /* = state*14 in GF(2^8) */

  const auto sx13_0123_sx9_1230 = Xor(sx13, TableLookupBytes(sx9, v1230));
  const auto sx14_0123_sx11_1230 = Xor(sx14, TableLookupBytes(sx11, v1230));
  const auto sx13_2301_sx9_3012 =
      TableLookupBytes(sx13_0123_sx9_1230, LoadDup128(du, k2301));
  return Xor(sx14_0123_sx11_1230, sx13_2301_sx9_3012);
}

}  // namespace detail

template <class V>  // u8
HWY_API V AESRound(V state, const V round_key) {
  // Intel docs swap the first two steps, but it does not matter because
  // ShiftRows is a permutation and SubBytes is independent of lane index.
  state = detail::SubBytes(state);
  state = detail::ShiftRows(state);
  state = detail::MixColumns(state);
  state = Xor(state, round_key);  // AddRoundKey
  return state;
}

template <class V>  // u8
HWY_API V AESLastRound(V state, const V round_key) {
  // LIke AESRound, but without MixColumns.
  state = detail::SubBytes(state);
  state = detail::ShiftRows(state);
  state = Xor(state, round_key);  // AddRoundKey
  return state;
}

template <class V>
HWY_API V AESInvMixColumns(V state) {
  return detail::InvMixColumns(state);
}

template <class V>  // u8
HWY_API V AESRoundInv(V state, const V round_key) {
  state = detail::InvSubBytes(state);
  state = detail::InvShiftRows(state);
  state = detail::InvMixColumns(state);
  state = Xor(state, round_key);  // AddRoundKey
  return state;
}

template <class V>  // u8
HWY_API V AESLastRoundInv(V state, const V round_key) {
  // Like AESRoundInv, but without InvMixColumns.
  state = detail::InvSubBytes(state);
  state = detail::InvShiftRows(state);
  state = Xor(state, round_key);  // AddRoundKey
  return state;
}

template <uint8_t kRcon, class V, HWY_IF_U8_D(DFromV<V>)>
HWY_API V AESKeyGenAssist(V v) {
  alignas(16) static constexpr uint8_t kRconXorMask[16] = {
      0, 0, 0, 0, kRcon, 0, 0, 0, 0, 0, 0, 0, kRcon, 0, 0, 0};
  alignas(16) static constexpr uint8_t kRotWordShuffle[16] = {
      4, 5, 6, 7, 5, 6, 7, 4, 12, 13, 14, 15, 13, 14, 15, 12};
  const DFromV<decltype(v)> d;
  const auto sub_word_result = detail::SubBytes(v);
  const auto rot_word_result =
      TableLookupBytes(sub_word_result, LoadDup128(d, kRotWordShuffle));
  return Xor(rot_word_result, LoadDup128(d, kRconXorMask));
}

// Constant-time implementation inspired by
// https://www.bearssl.org/constanttime.html, but about half the cost because we
// use 64x64 multiplies and 128-bit XORs.
template <class V>
HWY_API V CLMulLower(V a, V b) {
  const DFromV<V> d;
  static_assert(IsSame<TFromD<decltype(d)>, uint64_t>(), "V must be u64");
  const auto k1 = Set(d, 0x1111111111111111ULL);
  const auto k2 = Set(d, 0x2222222222222222ULL);
  const auto k4 = Set(d, 0x4444444444444444ULL);
  const auto k8 = Set(d, 0x8888888888888888ULL);
  const auto a0 = And(a, k1);
  const auto a1 = And(a, k2);
  const auto a2 = And(a, k4);
  const auto a3 = And(a, k8);
  const auto b0 = And(b, k1);
  const auto b1 = And(b, k2);
  const auto b2 = And(b, k4);
  const auto b3 = And(b, k8);

  auto m0 = Xor(MulEven(a0, b0), MulEven(a1, b3));
  auto m1 = Xor(MulEven(a0, b1), MulEven(a1, b0));
  auto m2 = Xor(MulEven(a0, b2), MulEven(a1, b1));
  auto m3 = Xor(MulEven(a0, b3), MulEven(a1, b2));
  m0 = Xor(m0, Xor(MulEven(a2, b2), MulEven(a3, b1)));
  m1 = Xor(m1, Xor(MulEven(a2, b3), MulEven(a3, b2)));
  m2 = Xor(m2, Xor(MulEven(a2, b0), MulEven(a3, b3)));
  m3 = Xor(m3, Xor(MulEven(a2, b1), MulEven(a3, b0)));
  return Or(Or(And(m0, k1), And(m1, k2)), Or(And(m2, k4), And(m3, k8)));
}

template <class V>
HWY_API V CLMulUpper(V a, V b) {
  const DFromV<V> d;
  static_assert(IsSame<TFromD<decltype(d)>, uint64_t>(), "V must be u64");
  const auto k1 = Set(d, 0x1111111111111111ULL);
  const auto k2 = Set(d, 0x2222222222222222ULL);
  const auto k4 = Set(d, 0x4444444444444444ULL);
  const auto k8 = Set(d, 0x8888888888888888ULL);
  const auto a0 = And(a, k1);
  const auto a1 = And(a, k2);
  const auto a2 = And(a, k4);
  const auto a3 = And(a, k8);
  const auto b0 = And(b, k1);
  const auto b1 = And(b, k2);
  const auto b2 = And(b, k4);
  const auto b3 = And(b, k8);

  auto m0 = Xor(MulOdd(a0, b0), MulOdd(a1, b3));
  auto m1 = Xor(MulOdd(a0, b1), MulOdd(a1, b0));
  auto m2 = Xor(MulOdd(a0, b2), MulOdd(a1, b1));
  auto m3 = Xor(MulOdd(a0, b3), MulOdd(a1, b2));
  m0 = Xor(m0, Xor(MulOdd(a2, b2), MulOdd(a3, b1)));
  m1 = Xor(m1, Xor(MulOdd(a2, b3), MulOdd(a3, b2)));
  m2 = Xor(m2, Xor(MulOdd(a2, b0), MulOdd(a3, b3)));
  m3 = Xor(m3, Xor(MulOdd(a2, b1), MulOdd(a3, b0)));
  return Or(Or(And(m0, k1), And(m1, k2)), Or(And(m2, k4), And(m3, k8)));
}

#endif  // HWY_NATIVE_AES
#endif  // HWY_TARGET != HWY_SCALAR

// ------------------------------ PopulationCount

// "Include guard": skip if native POPCNT-related instructions are available.
#if (defined(HWY_NATIVE_POPCNT) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_POPCNT
#undef HWY_NATIVE_POPCNT
#else
#define HWY_NATIVE_POPCNT
#endif

// This overload requires vectors to be at least 16 bytes, which is the case
// for LMUL >= 2.
#undef HWY_IF_POPCNT
#if HWY_TARGET == HWY_RVV
#define HWY_IF_POPCNT(D) \
  hwy::EnableIf<D().Pow2() >= 1 && D().MaxLanes() >= 16>* = nullptr
#else
// Other targets only have these two overloads which are mutually exclusive, so
// no further conditions are required.
#define HWY_IF_POPCNT(D) void* = nullptr
#endif  // HWY_TARGET == HWY_RVV

template <class V, class D = DFromV<V>, HWY_IF_U8_D(D),
          HWY_IF_V_SIZE_GT_D(D, 8), HWY_IF_POPCNT(D)>
HWY_API V PopulationCount(V v) {
  const D d;
  HWY_ALIGN constexpr uint8_t kLookup[16] = {
      0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
  };
  const auto lo = And(v, Set(d, uint8_t{0xF}));
  const auto hi = ShiftRight<4>(v);
  const auto lookup = LoadDup128(d, kLookup);
  return Add(TableLookupBytes(lookup, hi), TableLookupBytes(lookup, lo));
}

// RVV has a specialization that avoids the Set().
#if HWY_TARGET != HWY_RVV
// Slower fallback for capped vectors.
template <class V, class D = DFromV<V>, HWY_IF_U8_D(D),
          HWY_IF_V_SIZE_LE_D(D, 8)>
HWY_API V PopulationCount(V v) {
  const D d;
  // See https://arxiv.org/pdf/1611.07612.pdf, Figure 3
  const V k33 = Set(d, uint8_t{0x33});
  v = Sub(v, And(ShiftRight<1>(v), Set(d, uint8_t{0x55})));
  v = Add(And(ShiftRight<2>(v), k33), And(v, k33));
  return And(Add(v, ShiftRight<4>(v)), Set(d, uint8_t{0x0F}));
}
#endif  // HWY_TARGET != HWY_RVV

template <class V, class D = DFromV<V>, HWY_IF_U16_D(D)>
HWY_API V PopulationCount(V v) {
  const D d;
  const Repartition<uint8_t, decltype(d)> d8;
  const auto vals = BitCast(d, PopulationCount(BitCast(d8, v)));
  return Add(ShiftRight<8>(vals), And(vals, Set(d, uint16_t{0xFF})));
}

template <class V, class D = DFromV<V>, HWY_IF_U32_D(D)>
HWY_API V PopulationCount(V v) {
  const D d;
  Repartition<uint16_t, decltype(d)> d16;
  auto vals = BitCast(d, PopulationCount(BitCast(d16, v)));
  return Add(ShiftRight<16>(vals), And(vals, Set(d, uint32_t{0xFF})));
}

#if HWY_HAVE_INTEGER64
template <class V, class D = DFromV<V>, HWY_IF_U64_D(D)>
HWY_API V PopulationCount(V v) {
  const D d;
  Repartition<uint32_t, decltype(d)> d32;
  auto vals = BitCast(d, PopulationCount(BitCast(d32, v)));
  return Add(ShiftRight<32>(vals), And(vals, Set(d, 0xFFULL)));
}
#endif

#endif  // HWY_NATIVE_POPCNT

// ------------------------------ 8-bit multiplication

// "Include guard": skip if native 8-bit mul instructions are available.
#if (defined(HWY_NATIVE_MUL_8) == defined(HWY_TARGET_TOGGLE)) || HWY_IDE
#ifdef HWY_NATIVE_MUL_8
#undef HWY_NATIVE_MUL_8
#else
#define HWY_NATIVE_MUL_8
#endif

// 8 bit and fits in wider reg: promote
template <class V, HWY_IF_T_SIZE_V(V, 1),
          HWY_IF_V_SIZE_LE_V(V, HWY_MAX_BYTES / 2)>
HWY_API V operator*(const V a, const V b) {
  const DFromV<decltype(a)> d;
  const Rebind<MakeWide<TFromV<V>>, decltype(d)> dw;
  const RebindToUnsigned<decltype(d)> du;    // TruncateTo result
  const RebindToUnsigned<decltype(dw)> dwu;  // TruncateTo input
  const VFromD<decltype(dw)> mul = PromoteTo(dw, a) * PromoteTo(dw, b);
  // TruncateTo is cheaper than ConcatEven.
  return BitCast(d, TruncateTo(du, BitCast(dwu, mul)));
}

// 8 bit full reg: promote halves
template <class V, HWY_IF_T_SIZE_V(V, 1),
          HWY_IF_V_SIZE_GT_V(V, HWY_MAX_BYTES / 2)>
HWY_API V operator*(const V a, const V b) {
  const DFromV<decltype(a)> d;
  const Half<decltype(d)> dh;
  const Twice<RepartitionToWide<decltype(dh)>> dw;
  const VFromD<decltype(dw)> a0 = PromoteTo(dw, LowerHalf(dh, a));
  const VFromD<decltype(dw)> a1 = PromoteTo(dw, UpperHalf(dh, a));
  const VFromD<decltype(dw)> b0 = PromoteTo(dw, LowerHalf(dh, b));
  const VFromD<decltype(dw)> b1 = PromoteTo(dw, UpperHalf(dh, b));
  const VFromD<decltype(dw)> m0 = a0 * b0;
  const VFromD<decltype(dw)> m1 = a1 * b1;
  return ConcatEven(d, BitCast(d, m1), BitCast(d, m0));
}

#endif  // HWY_NATIVE_MUL_8

// ------------------------------ 64-bit multiplication

// "Include guard": skip if native 64-bit mul instructions are available.
#if (defined(HWY_NATIVE_MUL_64) == defined(HWY_TARGET_TOGGLE)) || HWY_IDE
#ifdef HWY_NATIVE_MUL_64
#undef HWY_NATIVE_MUL_64
#else
#define HWY_NATIVE_MUL_64
#endif

// Single-lane i64 or u64
template <class V, HWY_IF_T_SIZE_V(V, 8), HWY_IF_V_SIZE_V(V, 8),
          HWY_IF_NOT_FLOAT_V(V)>
HWY_API V operator*(V x, V y) {
  const DFromV<V> d;
  using T = TFromD<decltype(d)>;
  using TU = MakeUnsigned<T>;
  const TU xu = static_cast<TU>(GetLane(x));
  const TU yu = static_cast<TU>(GetLane(y));
  return Set(d, static_cast<T>(xu * yu));
}

template <class V, class D64 = DFromV<V>, HWY_IF_U64_D(D64),
          HWY_IF_V_SIZE_GT_D(D64, 8)>
HWY_API V operator*(V x, V y) {
  RepartitionToNarrow<D64> d32;
  auto x32 = BitCast(d32, x);
  auto y32 = BitCast(d32, y);
  auto lolo = BitCast(d32, MulEven(x32, y32));
  auto lohi = BitCast(d32, MulEven(x32, BitCast(d32, ShiftRight<32>(y))));
  auto hilo = BitCast(d32, MulEven(BitCast(d32, ShiftRight<32>(x)), y32));
  auto hi = BitCast(d32, ShiftLeft<32>(BitCast(D64{}, lohi + hilo)));
  return BitCast(D64{}, lolo + hi);
}
template <class V, class DI64 = DFromV<V>, HWY_IF_I64_D(DI64),
          HWY_IF_V_SIZE_GT_D(DI64, 8)>
HWY_API V operator*(V x, V y) {
  RebindToUnsigned<DI64> du64;
  return BitCast(DI64{}, BitCast(du64, x) * BitCast(du64, y));
}

#endif  // HWY_NATIVE_MUL_64

// ------------------------------ MulAdd / NegMulAdd

// "Include guard": skip if native int MulAdd instructions are available.
#if (defined(HWY_NATIVE_INT_FMA) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_INT_FMA
#undef HWY_NATIVE_INT_FMA
#else
#define HWY_NATIVE_INT_FMA
#endif

template <class V, HWY_IF_NOT_FLOAT_V(V)>
HWY_API V MulAdd(V mul, V x, V add) {
  return Add(Mul(mul, x), add);
}

template <class V, HWY_IF_NOT_FLOAT_V(V)>
HWY_API V NegMulAdd(V mul, V x, V add) {
  return Sub(add, Mul(mul, x));
}

#endif  // HWY_NATIVE_INT_FMA

// ------------------------------ SatWidenMulPairwiseAdd

#if (defined(HWY_NATIVE_U8_I8_SATWIDENMULPAIRWISEADD) == \
     defined(HWY_TARGET_TOGGLE))

#ifdef HWY_NATIVE_U8_I8_SATWIDENMULPAIRWISEADD
#undef HWY_NATIVE_U8_I8_SATWIDENMULPAIRWISEADD
#else
#define HWY_NATIVE_U8_I8_SATWIDENMULPAIRWISEADD
#endif

template <class DI16, class VU8, class VI8,
          class VU8_2 = Vec<Repartition<uint8_t, DI16>>, HWY_IF_I16_D(DI16),
          HWY_IF_U8_D(DFromV<VU8>), HWY_IF_I8_D(DFromV<VI8>),
          HWY_IF_LANES_D(DFromV<VU8>, HWY_MAX_LANES_V(VI8)),
          HWY_IF_LANES_D(DFromV<VU8>, HWY_MAX_LANES_V(VU8_2))>
HWY_API Vec<DI16> SatWidenMulPairwiseAdd(DI16 di16, VU8 a, VI8 b) {
  const RebindToUnsigned<decltype(di16)> du16;

  const auto a0 = And(BitCast(di16, a), Set(di16, int16_t{0x00FF}));
  const auto b0 = ShiftRight<8>(ShiftLeft<8>(BitCast(di16, b)));

  const auto a1 = BitCast(di16, ShiftRight<8>(BitCast(du16, a)));
  const auto b1 = ShiftRight<8>(BitCast(di16, b));

  return SaturatedAdd(Mul(a0, b0), Mul(a1, b1));
}

#endif

// ------------------------------ SumOfMulQuadAccumulate

#if (defined(HWY_NATIVE_I8_I8_SUMOFMULQUADACCUMULATE) == \
     defined(HWY_TARGET_TOGGLE))

#ifdef HWY_NATIVE_I8_I8_SUMOFMULQUADACCUMULATE
#undef HWY_NATIVE_I8_I8_SUMOFMULQUADACCUMULATE
#else
#define HWY_NATIVE_I8_I8_SUMOFMULQUADACCUMULATE
#endif

template <class DI32, HWY_IF_I32_D(DI32)>
HWY_API VFromD<DI32> SumOfMulQuadAccumulate(DI32 di32,
                                            VFromD<Repartition<int8_t, DI32>> a,
                                            VFromD<Repartition<int8_t, DI32>> b,
                                            VFromD<DI32> sum) {
  const Repartition<int16_t, decltype(di32)> di16;

  const auto a0 = ShiftRight<8>(ShiftLeft<8>(BitCast(di16, a)));
  const auto b0 = ShiftRight<8>(ShiftLeft<8>(BitCast(di16, b)));

  const auto a1 = ShiftRight<8>(BitCast(di16, a));
  const auto b1 = ShiftRight<8>(BitCast(di16, b));

  return Add(sum, Add(WidenMulPairwiseAdd(di32, a0, b0),
                      WidenMulPairwiseAdd(di32, a1, b1)));
}

#endif

#if (defined(HWY_NATIVE_U8_U8_SUMOFMULQUADACCUMULATE) == \
     defined(HWY_TARGET_TOGGLE))

#ifdef HWY_NATIVE_U8_U8_SUMOFMULQUADACCUMULATE
#undef HWY_NATIVE_U8_U8_SUMOFMULQUADACCUMULATE
#else
#define HWY_NATIVE_U8_U8_SUMOFMULQUADACCUMULATE
#endif

template <class DU32, HWY_IF_U32_D(DU32)>
HWY_API VFromD<DU32> SumOfMulQuadAccumulate(
    DU32 du32, VFromD<Repartition<uint8_t, DU32>> a,
    VFromD<Repartition<uint8_t, DU32>> b, VFromD<DU32> sum) {
  const Repartition<uint16_t, decltype(du32)> du16;
  const RebindToSigned<decltype(du16)> di16;
  const RebindToSigned<decltype(du32)> di32;

  const auto lo8_mask = Set(di16, int16_t{0x00FF});
  const auto a0 = And(BitCast(di16, a), lo8_mask);
  const auto b0 = And(BitCast(di16, b), lo8_mask);

  const auto a1 = BitCast(di16, ShiftRight<8>(BitCast(du16, a)));
  const auto b1 = BitCast(di16, ShiftRight<8>(BitCast(du16, b)));

  return Add(sum, Add(BitCast(du32, WidenMulPairwiseAdd(di32, a0, b0)),
                      BitCast(du32, WidenMulPairwiseAdd(di32, a1, b1))));
}

#endif

#if (defined(HWY_NATIVE_U8_I8_SUMOFMULQUADACCUMULATE) == \
     defined(HWY_TARGET_TOGGLE))

#ifdef HWY_NATIVE_U8_I8_SUMOFMULQUADACCUMULATE
#undef HWY_NATIVE_U8_I8_SUMOFMULQUADACCUMULATE
#else
#define HWY_NATIVE_U8_I8_SUMOFMULQUADACCUMULATE
#endif

template <class DI32, HWY_IF_I32_D(DI32)>
HWY_API VFromD<DI32> SumOfMulQuadAccumulate(
    DI32 di32, VFromD<Repartition<uint8_t, DI32>> a_u,
    VFromD<Repartition<int8_t, DI32>> b_i, VFromD<DI32> sum) {
  const Repartition<int16_t, decltype(di32)> di16;
  const RebindToUnsigned<decltype(di16)> du16;

  const auto a0 = And(BitCast(di16, a_u), Set(di16, int16_t{0x00FF}));
  const auto b0 = ShiftRight<8>(ShiftLeft<8>(BitCast(di16, b_i)));

  const auto a1 = BitCast(di16, ShiftRight<8>(BitCast(du16, a_u)));
  const auto b1 = ShiftRight<8>(BitCast(di16, b_i));

  // NOTE: SatWidenMulPairwiseAdd(di16, a_u, b_i) cannot be used in
  // SumOfMulQuadAccumulate as it is possible for
  // a_u[0]*b_i[0]+a_u[1]*b_i[1] to overflow an int16_t if a_u[0], b_i[0],
  // a_u[1], and b_i[1] are all non-zero and b_i[0] and b_i[1] have the same
  // sign.

  return Add(sum, Add(WidenMulPairwiseAdd(di32, a0, b0),
                      WidenMulPairwiseAdd(di32, a1, b1)));
}

#endif

#if (defined(HWY_NATIVE_I16_I16_SUMOFMULQUADACCUMULATE) == \
     defined(HWY_TARGET_TOGGLE))

#ifdef HWY_NATIVE_I16_I16_SUMOFMULQUADACCUMULATE
#undef HWY_NATIVE_I16_I16_SUMOFMULQUADACCUMULATE
#else
#define HWY_NATIVE_I16_I16_SUMOFMULQUADACCUMULATE
#endif

#if HWY_HAVE_INTEGER64
template <class DI64, HWY_IF_I64_D(DI64)>
HWY_API VFromD<DI64> SumOfMulQuadAccumulate(
    DI64 di64, VFromD<Repartition<int16_t, DI64>> a,
    VFromD<Repartition<int16_t, DI64>> b, VFromD<DI64> sum) {
  const Repartition<int32_t, decltype(di64)> di32;

  // WidenMulPairwiseAdd(di32, a, b) is okay here as
  // a[0]*b[0]+a[1]*b[1] is between -2147418112 and 2147483648 and as
  // a[0]*b[0]+a[1]*b[1] can only overflow an int32_t if
  // a[0], b[0], a[1], and b[1] are all equal to -32768.

  const auto i32_pairwise_sum = WidenMulPairwiseAdd(di32, a, b);
  const auto i32_pairwise_sum_overflow =
      VecFromMask(di32, Eq(i32_pairwise_sum, Set(di32, LimitsMin<int32_t>())));

  // The upper 32 bits of sum0 and sum1 need to be zeroed out in the case of
  // overflow.
  const auto hi32_mask = Set(di64, static_cast<int64_t>(~int64_t{0xFFFFFFFF}));
  const auto p0_zero_out_mask =
      ShiftLeft<32>(BitCast(di64, i32_pairwise_sum_overflow));
  const auto p1_zero_out_mask =
      And(BitCast(di64, i32_pairwise_sum_overflow), hi32_mask);

  const auto p0 =
      AndNot(p0_zero_out_mask,
             ShiftRight<32>(ShiftLeft<32>(BitCast(di64, i32_pairwise_sum))));
  const auto p1 =
      AndNot(p1_zero_out_mask, ShiftRight<32>(BitCast(di64, i32_pairwise_sum)));

  return Add(sum, Add(p0, p1));
}
#endif  // HWY_HAVE_INTEGER64
#endif  // HWY_NATIVE_I16_I16_SUMOFMULQUADACCUMULATE

#if (defined(HWY_NATIVE_U16_U16_SUMOFMULQUADACCUMULATE) == \
     defined(HWY_TARGET_TOGGLE))

#ifdef HWY_NATIVE_U16_U16_SUMOFMULQUADACCUMULATE
#undef HWY_NATIVE_U16_U16_SUMOFMULQUADACCUMULATE
#else
#define HWY_NATIVE_U16_U16_SUMOFMULQUADACCUMULATE
#endif

#if HWY_HAVE_INTEGER64
template <class DU64, HWY_IF_U64_D(DU64)>
HWY_API VFromD<DU64> SumOfMulQuadAccumulate(
    DU64 du64, VFromD<Repartition<uint16_t, DU64>> a,
    VFromD<Repartition<uint16_t, DU64>> b, VFromD<DU64> sum) {
  const auto u32_even_prod = MulEven(a, b);
  const auto u32_odd_prod = MulOdd(a, b);

  const auto lo32_mask = Set(du64, uint64_t{0xFFFFFFFFu});

  const auto p0 = Add(And(BitCast(du64, u32_even_prod), lo32_mask),
                      And(BitCast(du64, u32_odd_prod), lo32_mask));
  const auto p1 = Add(ShiftRight<32>(BitCast(du64, u32_even_prod)),
                      ShiftRight<32>(BitCast(du64, u32_odd_prod)));

  return Add(sum, Add(p0, p1));
}
#endif  // HWY_HAVE_INTEGER64
#endif  // HWY_NATIVE_U16_U16_SUMOFMULQUADACCUMULATE

// ------------------------------ F64 ApproximateReciprocal

#if (defined(HWY_NATIVE_F64_APPROX_RECIP) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_F64_APPROX_RECIP
#undef HWY_NATIVE_F64_APPROX_RECIP
#else
#define HWY_NATIVE_F64_APPROX_RECIP
#endif

#if HWY_HAVE_FLOAT64
template <class V, HWY_IF_F64_D(DFromV<V>)>
HWY_API V ApproximateReciprocal(V v) {
  const DFromV<decltype(v)> d;
  return Div(Set(d, 1.0), v);
}
#endif  // HWY_HAVE_FLOAT64

#endif  // HWY_NATIVE_F64_APPROX_RECIP

// ------------------------------ F64 ApproximateReciprocalSqrt

#if (defined(HWY_NATIVE_F64_APPROX_RSQRT) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_F64_APPROX_RSQRT
#undef HWY_NATIVE_F64_APPROX_RSQRT
#else
#define HWY_NATIVE_F64_APPROX_RSQRT
#endif

#if HWY_HAVE_FLOAT64
template <class V, HWY_IF_F64_D(DFromV<V>)>
HWY_API V ApproximateReciprocalSqrt(V v) {
  const DFromV<decltype(v)> d;
  const RebindToUnsigned<decltype(d)> du;
  const auto half = Mul(v, Set(d, 0.5));
  // Initial guess based on log2(f)
  const auto guess = BitCast(d, Sub(Set(du, uint64_t{0x5FE6EB50C7B537A9u}),
                                    ShiftRight<1>(BitCast(du, v))));
  // One Newton-Raphson iteration
  return Mul(guess, NegMulAdd(Mul(half, guess), guess, Set(d, 1.5)));
}
#endif  // HWY_HAVE_FLOAT64

#endif  // HWY_NATIVE_F64_APPROX_RSQRT

// ------------------------------ Compress*

// "Include guard": skip if native 8-bit compress instructions are available.
#if (defined(HWY_NATIVE_COMPRESS8) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_COMPRESS8
#undef HWY_NATIVE_COMPRESS8
#else
#define HWY_NATIVE_COMPRESS8
#endif

template <class V, class D, typename T, HWY_IF_T_SIZE(T, 1)>
HWY_API size_t CompressBitsStore(V v, const uint8_t* HWY_RESTRICT bits, D d,
                                 T* unaligned) {
  HWY_ALIGN T lanes[MaxLanes(d)];
  Store(v, d, lanes);

  const Simd<T, HWY_MIN(MaxLanes(d), 8), 0> d8;
  T* HWY_RESTRICT pos = unaligned;

  HWY_ALIGN constexpr T table[2048] = {
      0, 1, 2, 3, 4, 5, 6, 7, /**/ 0, 1, 2, 3, 4, 5, 6, 7,  //
      1, 0, 2, 3, 4, 5, 6, 7, /**/ 0, 1, 2, 3, 4, 5, 6, 7,  //
      2, 0, 1, 3, 4, 5, 6, 7, /**/ 0, 2, 1, 3, 4, 5, 6, 7,  //
      1, 2, 0, 3, 4, 5, 6, 7, /**/ 0, 1, 2, 3, 4, 5, 6, 7,  //
      3, 0, 1, 2, 4, 5, 6, 7, /**/ 0, 3, 1, 2, 4, 5, 6, 7,  //
      1, 3, 0, 2, 4, 5, 6, 7, /**/ 0, 1, 3, 2, 4, 5, 6, 7,  //
      2, 3, 0, 1, 4, 5, 6, 7, /**/ 0, 2, 3, 1, 4, 5, 6, 7,  //
      1, 2, 3, 0, 4, 5, 6, 7, /**/ 0, 1, 2, 3, 4, 5, 6, 7,  //
      4, 0, 1, 2, 3, 5, 6, 7, /**/ 0, 4, 1, 2, 3, 5, 6, 7,  //
      1, 4, 0, 2, 3, 5, 6, 7, /**/ 0, 1, 4, 2, 3, 5, 6, 7,  //
      2, 4, 0, 1, 3, 5, 6, 7, /**/ 0, 2, 4, 1, 3, 5, 6, 7,  //
      1, 2, 4, 0, 3, 5, 6, 7, /**/ 0, 1, 2, 4, 3, 5, 6, 7,  //
      3, 4, 0, 1, 2, 5, 6, 7, /**/ 0, 3, 4, 1, 2, 5, 6, 7,  //
      1, 3, 4, 0, 2, 5, 6, 7, /**/ 0, 1, 3, 4, 2, 5, 6, 7,  //
      2, 3, 4, 0, 1, 5, 6, 7, /**/ 0, 2, 3, 4, 1, 5, 6, 7,  //
      1, 2, 3, 4, 0, 5, 6, 7, /**/ 0, 1, 2, 3, 4, 5, 6, 7,  //
      5, 0, 1, 2, 3, 4, 6, 7, /**/ 0, 5, 1, 2, 3, 4, 6, 7,  //
      1, 5, 0, 2, 3, 4, 6, 7, /**/ 0, 1, 5, 2, 3, 4, 6, 7,  //
      2, 5, 0, 1, 3, 4, 6, 7, /**/ 0, 2, 5, 1, 3, 4, 6, 7,  //
      1, 2, 5, 0, 3, 4, 6, 7, /**/ 0, 1, 2, 5, 3, 4, 6, 7,  //
      3, 5, 0, 1, 2, 4, 6, 7, /**/ 0, 3, 5, 1, 2, 4, 6, 7,  //
      1, 3, 5, 0, 2, 4, 6, 7, /**/ 0, 1, 3, 5, 2, 4, 6, 7,  //
      2, 3, 5, 0, 1, 4, 6, 7, /**/ 0, 2, 3, 5, 1, 4, 6, 7,  //
      1, 2, 3, 5, 0, 4, 6, 7, /**/ 0, 1, 2, 3, 5, 4, 6, 7,  //
      4, 5, 0, 1, 2, 3, 6, 7, /**/ 0, 4, 5, 1, 2, 3, 6, 7,  //
      1, 4, 5, 0, 2, 3, 6, 7, /**/ 0, 1, 4, 5, 2, 3, 6, 7,  //
      2, 4, 5, 0, 1, 3, 6, 7, /**/ 0, 2, 4, 5, 1, 3, 6, 7,  //
      1, 2, 4, 5, 0, 3, 6, 7, /**/ 0, 1, 2, 4, 5, 3, 6, 7,  //
      3, 4, 5, 0, 1, 2, 6, 7, /**/ 0, 3, 4, 5, 1, 2, 6, 7,  //
      1, 3, 4, 5, 0, 2, 6, 7, /**/ 0, 1, 3, 4, 5, 2, 6, 7,  //
      2, 3, 4, 5, 0, 1, 6, 7, /**/ 0, 2, 3, 4, 5, 1, 6, 7,  //
      1, 2, 3, 4, 5, 0, 6, 7, /**/ 0, 1, 2, 3, 4, 5, 6, 7,  //
      6, 0, 1, 2, 3, 4, 5, 7, /**/ 0, 6, 1, 2, 3, 4, 5, 7,  //
      1, 6, 0, 2, 3, 4, 5, 7, /**/ 0, 1, 6, 2, 3, 4, 5, 7,  //
      2, 6, 0, 1, 3, 4, 5, 7, /**/ 0, 2, 6, 1, 3, 4, 5, 7,  //
      1, 2, 6, 0, 3, 4, 5, 7, /**/ 0, 1, 2, 6, 3, 4, 5, 7,  //
      3, 6, 0, 1, 2, 4, 5, 7, /**/ 0, 3, 6, 1, 2, 4, 5, 7,  //
      1, 3, 6, 0, 2, 4, 5, 7, /**/ 0, 1, 3, 6, 2, 4, 5, 7,  //
      2, 3, 6, 0, 1, 4, 5, 7, /**/ 0, 2, 3, 6, 1, 4, 5, 7,  //
      1, 2, 3, 6, 0, 4, 5, 7, /**/ 0, 1, 2, 3, 6, 4, 5, 7,  //
      4, 6, 0, 1, 2, 3, 5, 7, /**/ 0, 4, 6, 1, 2, 3, 5, 7,  //
      1, 4, 6, 0, 2, 3, 5, 7, /**/ 0, 1, 4, 6, 2, 3, 5, 7,  //
      2, 4, 6, 0, 1, 3, 5, 7, /**/ 0, 2, 4, 6, 1, 3, 5, 7,  //
      1, 2, 4, 6, 0, 3, 5, 7, /**/ 0, 1, 2, 4, 6, 3, 5, 7,  //
      3, 4, 6, 0, 1, 2, 5, 7, /**/ 0, 3, 4, 6, 1, 2, 5, 7,  //
      1, 3, 4, 6, 0, 2, 5, 7, /**/ 0, 1, 3, 4, 6, 2, 5, 7,  //
      2, 3, 4, 6, 0, 1, 5, 7, /**/ 0, 2, 3, 4, 6, 1, 5, 7,  //
      1, 2, 3, 4, 6, 0, 5, 7, /**/ 0, 1, 2, 3, 4, 6, 5, 7,  //
      5, 6, 0, 1, 2, 3, 4, 7, /**/ 0, 5, 6, 1, 2, 3, 4, 7,  //
      1, 5, 6, 0, 2, 3, 4, 7, /**/ 0, 1, 5, 6, 2, 3, 4, 7,  //
      2, 5, 6, 0, 1, 3, 4, 7, /**/ 0, 2, 5, 6, 1, 3, 4, 7,  //
      1, 2, 5, 6, 0, 3, 4, 7, /**/ 0, 1, 2, 5, 6, 3, 4, 7,  //
      3, 5, 6, 0, 1, 2, 4, 7, /**/ 0, 3, 5, 6, 1, 2, 4, 7,  //
      1, 3, 5, 6, 0, 2, 4, 7, /**/ 0, 1, 3, 5, 6, 2, 4, 7,  //
      2, 3, 5, 6, 0, 1, 4, 7, /**/ 0, 2, 3, 5, 6, 1, 4, 7,  //
      1, 2, 3, 5, 6, 0, 4, 7, /**/ 0, 1, 2, 3, 5, 6, 4, 7,  //
      4, 5, 6, 0, 1, 2, 3, 7, /**/ 0, 4, 5, 6, 1, 2, 3, 7,  //
      1, 4, 5, 6, 0, 2, 3, 7, /**/ 0, 1, 4, 5, 6, 2, 3, 7,  //
      2, 4, 5, 6, 0, 1, 3, 7, /**/ 0, 2, 4, 5, 6, 1, 3, 7,  //
      1, 2, 4, 5, 6, 0, 3, 7, /**/ 0, 1, 2, 4, 5, 6, 3, 7,  //
      3, 4, 5, 6, 0, 1, 2, 7, /**/ 0, 3, 4, 5, 6, 1, 2, 7,  //
      1, 3, 4, 5, 6, 0, 2, 7, /**/ 0, 1, 3, 4, 5, 6, 2, 7,  //
      2, 3, 4, 5, 6, 0, 1, 7, /**/ 0, 2, 3, 4, 5, 6, 1, 7,  //
      1, 2, 3, 4, 5, 6, 0, 7, /**/ 0, 1, 2, 3, 4, 5, 6, 7,  //
      7, 0, 1, 2, 3, 4, 5, 6, /**/ 0, 7, 1, 2, 3, 4, 5, 6,  //
      1, 7, 0, 2, 3, 4, 5, 6, /**/ 0, 1, 7, 2, 3, 4, 5, 6,  //
      2, 7, 0, 1, 3, 4, 5, 6, /**/ 0, 2, 7, 1, 3, 4, 5, 6,  //
      1, 2, 7, 0, 3, 4, 5, 6, /**/ 0, 1, 2, 7, 3, 4, 5, 6,  //
      3, 7, 0, 1, 2, 4, 5, 6, /**/ 0, 3, 7, 1, 2, 4, 5, 6,  //
      1, 3, 7, 0, 2, 4, 5, 6, /**/ 0, 1, 3, 7, 2, 4, 5, 6,  //
      2, 3, 7, 0, 1, 4, 5, 6, /**/ 0, 2, 3, 7, 1, 4, 5, 6,  //
      1, 2, 3, 7, 0, 4, 5, 6, /**/ 0, 1, 2, 3, 7, 4, 5, 6,  //
      4, 7, 0, 1, 2, 3, 5, 6, /**/ 0, 4, 7, 1, 2, 3, 5, 6,  //
      1, 4, 7, 0, 2, 3, 5, 6, /**/ 0, 1, 4, 7, 2, 3, 5, 6,  //
      2, 4, 7, 0, 1, 3, 5, 6, /**/ 0, 2, 4, 7, 1, 3, 5, 6,  //
      1, 2, 4, 7, 0, 3, 5, 6, /**/ 0, 1, 2, 4, 7, 3, 5, 6,  //
      3, 4, 7, 0, 1, 2, 5, 6, /**/ 0, 3, 4, 7, 1, 2, 5, 6,  //
      1, 3, 4, 7, 0, 2, 5, 6, /**/ 0, 1, 3, 4, 7, 2, 5, 6,  //
      2, 3, 4, 7, 0, 1, 5, 6, /**/ 0, 2, 3, 4, 7, 1, 5, 6,  //
      1, 2, 3, 4, 7, 0, 5, 6, /**/ 0, 1, 2, 3, 4, 7, 5, 6,  //
      5, 7, 0, 1, 2, 3, 4, 6, /**/ 0, 5, 7, 1, 2, 3, 4, 6,  //
      1, 5, 7, 0, 2, 3, 4, 6, /**/ 0, 1, 5, 7, 2, 3, 4, 6,  //
      2, 5, 7, 0, 1, 3, 4, 6, /**/ 0, 2, 5, 7, 1, 3, 4, 6,  //
      1, 2, 5, 7, 0, 3, 4, 6, /**/ 0, 1, 2, 5, 7, 3, 4, 6,  //
      3, 5, 7, 0, 1, 2, 4, 6, /**/ 0, 3, 5, 7, 1, 2, 4, 6,  //
      1, 3, 5, 7, 0, 2, 4, 6, /**/ 0, 1, 3, 5, 7, 2, 4, 6,  //
      2, 3, 5, 7, 0, 1, 4, 6, /**/ 0, 2, 3, 5, 7, 1, 4, 6,  //
      1, 2, 3, 5, 7, 0, 4, 6, /**/ 0, 1, 2, 3, 5, 7, 4, 6,  //
      4, 5, 7, 0, 1, 2, 3, 6, /**/ 0, 4, 5, 7, 1, 2, 3, 6,  //
      1, 4, 5, 7, 0, 2, 3, 6, /**/ 0, 1, 4, 5, 7, 2, 3, 6,  //
      2, 4, 5, 7, 0, 1, 3, 6, /**/ 0, 2, 4, 5, 7, 1, 3, 6,  //
      1, 2, 4, 5, 7, 0, 3, 6, /**/ 0, 1, 2, 4, 5, 7, 3, 6,  //
      3, 4, 5, 7, 0, 1, 2, 6, /**/ 0, 3, 4, 5, 7, 1, 2, 6,  //
      1, 3, 4, 5, 7, 0, 2, 6, /**/ 0, 1, 3, 4, 5, 7, 2, 6,  //
      2, 3, 4, 5, 7, 0, 1, 6, /**/ 0, 2, 3, 4, 5, 7, 1, 6,  //
      1, 2, 3, 4, 5, 7, 0, 6, /**/ 0, 1, 2, 3, 4, 5, 7, 6,  //
      6, 7, 0, 1, 2, 3, 4, 5, /**/ 0, 6, 7, 1, 2, 3, 4, 5,  //
      1, 6, 7, 0, 2, 3, 4, 5, /**/ 0, 1, 6, 7, 2, 3, 4, 5,  //
      2, 6, 7, 0, 1, 3, 4, 5, /**/ 0, 2, 6, 7, 1, 3, 4, 5,  //
      1, 2, 6, 7, 0, 3, 4, 5, /**/ 0, 1, 2, 6, 7, 3, 4, 5,  //
      3, 6, 7, 0, 1, 2, 4, 5, /**/ 0, 3, 6, 7, 1, 2, 4, 5,  //
      1, 3, 6, 7, 0, 2, 4, 5, /**/ 0, 1, 3, 6, 7, 2, 4, 5,  //
      2, 3, 6, 7, 0, 1, 4, 5, /**/ 0, 2, 3, 6, 7, 1, 4, 5,  //
      1, 2, 3, 6, 7, 0, 4, 5, /**/ 0, 1, 2, 3, 6, 7, 4, 5,  //
      4, 6, 7, 0, 1, 2, 3, 5, /**/ 0, 4, 6, 7, 1, 2, 3, 5,  //
      1, 4, 6, 7, 0, 2, 3, 5, /**/ 0, 1, 4, 6, 7, 2, 3, 5,  //
      2, 4, 6, 7, 0, 1, 3, 5, /**/ 0, 2, 4, 6, 7, 1, 3, 5,  //
      1, 2, 4, 6, 7, 0, 3, 5, /**/ 0, 1, 2, 4, 6, 7, 3, 5,  //
      3, 4, 6, 7, 0, 1, 2, 5, /**/ 0, 3, 4, 6, 7, 1, 2, 5,  //
      1, 3, 4, 6, 7, 0, 2, 5, /**/ 0, 1, 3, 4, 6, 7, 2, 5,  //
      2, 3, 4, 6, 7, 0, 1, 5, /**/ 0, 2, 3, 4, 6, 7, 1, 5,  //
      1, 2, 3, 4, 6, 7, 0, 5, /**/ 0, 1, 2, 3, 4, 6, 7, 5,  //
      5, 6, 7, 0, 1, 2, 3, 4, /**/ 0, 5, 6, 7, 1, 2, 3, 4,  //
      1, 5, 6, 7, 0, 2, 3, 4, /**/ 0, 1, 5, 6, 7, 2, 3, 4,  //
      2, 5, 6, 7, 0, 1, 3, 4, /**/ 0, 2, 5, 6, 7, 1, 3, 4,  //
      1, 2, 5, 6, 7, 0, 3, 4, /**/ 0, 1, 2, 5, 6, 7, 3, 4,  //
      3, 5, 6, 7, 0, 1, 2, 4, /**/ 0, 3, 5, 6, 7, 1, 2, 4,  //
      1, 3, 5, 6, 7, 0, 2, 4, /**/ 0, 1, 3, 5, 6, 7, 2, 4,  //
      2, 3, 5, 6, 7, 0, 1, 4, /**/ 0, 2, 3, 5, 6, 7, 1, 4,  //
      1, 2, 3, 5, 6, 7, 0, 4, /**/ 0, 1, 2, 3, 5, 6, 7, 4,  //
      4, 5, 6, 7, 0, 1, 2, 3, /**/ 0, 4, 5, 6, 7, 1, 2, 3,  //
      1, 4, 5, 6, 7, 0, 2, 3, /**/ 0, 1, 4, 5, 6, 7, 2, 3,  //
      2, 4, 5, 6, 7, 0, 1, 3, /**/ 0, 2, 4, 5, 6, 7, 1, 3,  //
      1, 2, 4, 5, 6, 7, 0, 3, /**/ 0, 1, 2, 4, 5, 6, 7, 3,  //
      3, 4, 5, 6, 7, 0, 1, 2, /**/ 0, 3, 4, 5, 6, 7, 1, 2,  //
      1, 3, 4, 5, 6, 7, 0, 2, /**/ 0, 1, 3, 4, 5, 6, 7, 2,  //
      2, 3, 4, 5, 6, 7, 0, 1, /**/ 0, 2, 3, 4, 5, 6, 7, 1,  //
      1, 2, 3, 4, 5, 6, 7, 0, /**/ 0, 1, 2, 3, 4, 5, 6, 7};

  for (size_t i = 0; i < Lanes(d); i += 8) {
    // Each byte worth of bits is the index of one of 256 8-byte ranges, and its
    // population count determines how far to advance the write position.
    const size_t bits8 = bits[i / 8];
    const auto indices = Load(d8, table + bits8 * 8);
    const auto compressed = TableLookupBytes(LoadU(d8, lanes + i), indices);
    StoreU(compressed, d8, pos);
    pos += PopCount(bits8);
  }
  return static_cast<size_t>(pos - unaligned);
}

template <class V, class M, class D, typename T, HWY_IF_T_SIZE(T, 1)>
HWY_API size_t CompressStore(V v, M mask, D d, T* HWY_RESTRICT unaligned) {
  uint8_t bits[HWY_MAX(size_t{8}, MaxLanes(d) / 8)];
  (void)StoreMaskBits(d, mask, bits);
  return CompressBitsStore(v, bits, d, unaligned);
}

template <class V, class M, class D, typename T, HWY_IF_T_SIZE(T, 1)>
HWY_API size_t CompressBlendedStore(V v, M mask, D d,
                                    T* HWY_RESTRICT unaligned) {
  HWY_ALIGN T buf[MaxLanes(d)];
  const size_t bytes = CompressStore(v, mask, d, buf);
  BlendedStore(Load(d, buf), FirstN(d, bytes), d, unaligned);
  return bytes;
}

// For reasons unknown, HWY_IF_T_SIZE_V is a compile error in SVE.
template <class V, class M, typename T = TFromV<V>, HWY_IF_T_SIZE(T, 1)>
HWY_API V Compress(V v, const M mask) {
  const DFromV<V> d;
  HWY_ALIGN T lanes[MaxLanes(d)];
  (void)CompressStore(v, mask, d, lanes);
  return Load(d, lanes);
}

template <class V, typename T = TFromV<V>, HWY_IF_T_SIZE(T, 1)>
HWY_API V CompressBits(V v, const uint8_t* HWY_RESTRICT bits) {
  const DFromV<V> d;
  HWY_ALIGN T lanes[MaxLanes(d)];
  (void)CompressBitsStore(v, bits, d, lanes);
  return Load(d, lanes);
}

template <class V, class M, typename T = TFromV<V>, HWY_IF_T_SIZE(T, 1)>
HWY_API V CompressNot(V v, M mask) {
  return Compress(v, Not(mask));
}

#endif  // HWY_NATIVE_COMPRESS8

// ------------------------------ Expand

// "Include guard": skip if native 8/16-bit Expand/LoadExpand are available.
// Note that this generic implementation assumes <= 128 bit fixed vectors;
// the SVE and RVV targets provide their own native implementations.
#if (defined(HWY_NATIVE_EXPAND) == defined(HWY_TARGET_TOGGLE)) || HWY_IDE
#ifdef HWY_NATIVE_EXPAND
#undef HWY_NATIVE_EXPAND
#else
#define HWY_NATIVE_EXPAND
#endif

namespace detail {

#if HWY_IDE
template <class M>
HWY_INLINE uint64_t BitsFromMask(M /* mask */) {
  return 0;
}
#endif  // HWY_IDE

template <size_t N>
HWY_INLINE Vec128<uint8_t, N> IndicesForExpandFromBits(uint64_t mask_bits) {
  static_assert(N <= 8, "Should only be called for half-vectors");
  const Simd<uint8_t, N, 0> du8;
  HWY_DASSERT(mask_bits < 0x100);
  alignas(16) static constexpr uint8_t table[2048] = {
      // PrintExpand8x8Tables
      128, 128, 128, 128, 128, 128, 128, 128,  //
      0,   128, 128, 128, 128, 128, 128, 128,  //
      128, 0,   128, 128, 128, 128, 128, 128,  //
      0,   1,   128, 128, 128, 128, 128, 128,  //
      128, 128, 0,   128, 128, 128, 128, 128,  //
      0,   128, 1,   128, 128, 128, 128, 128,  //
      128, 0,   1,   128, 128, 128, 128, 128,  //
      0,   1,   2,   128, 128, 128, 128, 128,  //
      128, 128, 128, 0,   128, 128, 128, 128,  //
      0,   128, 128, 1,   128, 128, 128, 128,  //
      128, 0,   128, 1,   128, 128, 128, 128,  //
      0,   1,   128, 2,   128, 128, 128, 128,  //
      128, 128, 0,   1,   128, 128, 128, 128,  //
      0,   128, 1,   2,   128, 128, 128, 128,  //
      128, 0,   1,   2,   128, 128, 128, 128,  //
      0,   1,   2,   3,   128, 128, 128, 128,  //
      128, 128, 128, 128, 0,   128, 128, 128,  //
      0,   128, 128, 128, 1,   128, 128, 128,  //
      128, 0,   128, 128, 1,   128, 128, 128,  //
      0,   1,   128, 128, 2,   128, 128, 128,  //
      128, 128, 0,   128, 1,   128, 128, 128,  //
      0,   128, 1,   128, 2,   128, 128, 128,  //
      128, 0,   1,   128, 2,   128, 128, 128,  //
      0,   1,   2,   128, 3,   128, 128, 128,  //
      128, 128, 128, 0,   1,   128, 128, 128,  //
      0,   128, 128, 1,   2,   128, 128, 128,  //
      128, 0,   128, 1,   2,   128, 128, 128,  //
      0,   1,   128, 2,   3,   128, 128, 128,  //
      128, 128, 0,   1,   2,   128, 128, 128,  //
      0,   128, 1,   2,   3,   128, 128, 128,  //
      128, 0,   1,   2,   3,   128, 128, 128,  //
      0,   1,   2,   3,   4,   128, 128, 128,  //
      128, 128, 128, 128, 128, 0,   128, 128,  //
      0,   128, 128, 128, 128, 1,   128, 128,  //
      128, 0,   128, 128, 128, 1,   128, 128,  //
      0,   1,   128, 128, 128, 2,   128, 128,  //
      128, 128, 0,   128, 128, 1,   128, 128,  //
      0,   128, 1,   128, 128, 2,   128, 128,  //
      128, 0,   1,   128, 128, 2,   128, 128,  //
      0,   1,   2,   128, 128, 3,   128, 128,  //
      128, 128, 128, 0,   128, 1,   128, 128,  //
      0,   128, 128, 1,   128, 2,   128, 128,  //
      128, 0,   128, 1,   128, 2,   128, 128,  //
      0,   1,   128, 2,   128, 3,   128, 128,  //
      128, 128, 0,   1,   128, 2,   128, 128,  //
      0,   128, 1,   2,   128, 3,   128, 128,  //
      128, 0,   1,   2,   128, 3,   128, 128,  //
      0,   1,   2,   3,   128, 4,   128, 128,  //
      128, 128, 128, 128, 0,   1,   128, 128,  //
      0,   128, 128, 128, 1,   2,   128, 128,  //
      128, 0,   128, 128, 1,   2,   128, 128,  //
      0,   1,   128, 128, 2,   3,   128, 128,  //
      128, 128, 0,   128, 1,   2,   128, 128,  //
      0,   128, 1,   128, 2,   3,   128, 128,  //
      128, 0,   1,   128, 2,   3,   128, 128,  //
      0,   1,   2,   128, 3,   4,   128, 128,  //
      128, 128, 128, 0,   1,   2,   128, 128,  //
      0,   128, 128, 1,   2,   3,   128, 128,  //
      128, 0,   128, 1,   2,   3,   128, 128,  //
      0,   1,   128, 2,   3,   4,   128, 128,  //
      128, 128, 0,   1,   2,   3,   128, 128,  //
      0,   128, 1,   2,   3,   4,   128, 128,  //
      128, 0,   1,   2,   3,   4,   128, 128,  //
      0,   1,   2,   3,   4,   5,   128, 128,  //
      128, 128, 128, 128, 128, 128, 0,   128,  //
      0,   128, 128, 128, 128, 128, 1,   128,  //
      128, 0,   128, 128, 128, 128, 1,   128,  //
      0,   1,   128, 128, 128, 128, 2,   128,  //
      128, 128, 0,   128, 128, 128, 1,   128,  //
      0,   128, 1,   128, 128, 128, 2,   128,  //
      128, 0,   1,   128, 128, 128, 2,   128,  //
      0,   1,   2,   128, 128, 128, 3,   128,  //
      128, 128, 128, 0,   128, 128, 1,   128,  //
      0,   128, 128, 1,   128, 128, 2,   128,  //
      128, 0,   128, 1,   128, 128, 2,   128,  //
      0,   1,   128, 2,   128, 128, 3,   128,  //
      128, 128, 0,   1,   128, 128, 2,   128,  //
      0,   128, 1,   2,   128, 128, 3,   128,  //
      128, 0,   1,   2,   128, 128, 3,   128,  //
      0,   1,   2,   3,   128, 128, 4,   128,  //
      128, 128, 128, 128, 0,   128, 1,   128,  //
      0,   128, 128, 128, 1,   128, 2,   128,  //
      128, 0,   128, 128, 1,   128, 2,   128,  //
      0,   1,   128, 128, 2,   128, 3,   128,  //
      128, 128, 0,   128, 1,   128, 2,   128,  //
      0,   128, 1,   128, 2,   128, 3,   128,  //
      128, 0,   1,   128, 2,   128, 3,   128,  //
      0,   1,   2,   128, 3,   128, 4,   128,  //
      128, 128, 128, 0,   1,   128, 2,   128,  //
      0,   128, 128, 1,   2,   128, 3,   128,  //
      128, 0,   128, 1,   2,   128, 3,   128,  //
      0,   1,   128, 2,   3,   128, 4,   128,  //
      128, 128, 0,   1,   2,   128, 3,   128,  //
      0,   128, 1,   2,   3,   128, 4,   128,  //
      128, 0,   1,   2,   3,   128, 4,   128,  //
      0,   1,   2,   3,   4,   128, 5,   128,  //
      128, 128, 128, 128, 128, 0,   1,   128,  //
      0,   128, 128, 128, 128, 1,   2,   128,  //
      128, 0,   128, 128, 128, 1,   2,   128,  //
      0,   1,   128, 128, 128, 2,   3,   128,  //
      128, 128, 0,   128, 128, 1,   2,   128,  //
      0,   128, 1,   128, 128, 2,   3,   128,  //
      128, 0,   1,   128, 128, 2,   3,   128,  //
      0,   1,   2,   128, 128, 3,   4,   128,  //
      128, 128, 128, 0,   128, 1,   2,   128,  //
      0,   128, 128, 1,   128, 2,   3,   128,  //
      128, 0,   128, 1,   128, 2,   3,   128,  //
      0,   1,   128, 2,   128, 3,   4,   128,  //
      128, 128, 0,   1,   128, 2,   3,   128,  //
      0,   128, 1,   2,   128, 3,   4,   128,  //
      128, 0,   1,   2,   128, 3,   4,   128,  //
      0,   1,   2,   3,   128, 4,   5,   128,  //
      128, 128, 128, 128, 0,   1,   2,   128,  //
      0,   128, 128, 128, 1,   2,   3,   128,  //
      128, 0,   128, 128, 1,   2,   3,   128,  //
      0,   1,   128, 128, 2,   3,   4,   128,  //
      128, 128, 0,   128, 1,   2,   3,   128,  //
      0,   128, 1,   128, 2,   3,   4,   128,  //
      128, 0,   1,   128, 2,   3,   4,   128,  //
      0,   1,   2,   128, 3,   4,   5,   128,  //
      128, 128, 128, 0,   1,   2,   3,   128,  //
      0,   128, 128, 1,   2,   3,   4,   128,  //
      128, 0,   128, 1,   2,   3,   4,   128,  //
      0,   1,   128, 2,   3,   4,   5,   128,  //
      128, 128, 0,   1,   2,   3,   4,   128,  //
      0,   128, 1,   2,   3,   4,   5,   128,  //
      128, 0,   1,   2,   3,   4,   5,   128,  //
      0,   1,   2,   3,   4,   5,   6,   128,  //
      128, 128, 128, 128, 128, 128, 128, 0,    //
      0,   128, 128, 128, 128, 128, 128, 1,    //
      128, 0,   128, 128, 128, 128, 128, 1,    //
      0,   1,   128, 128, 128, 128, 128, 2,    //
      128, 128, 0,   128, 128, 128, 128, 1,    //
      0,   128, 1,   128, 128, 128, 128, 2,    //
      128, 0,   1,   128, 128, 128, 128, 2,    //
      0,   1,   2,   128, 128, 128, 128, 3,    //
      128, 128, 128, 0,   128, 128, 128, 1,    //
      0,   128, 128, 1,   128, 128, 128, 2,    //
      128, 0,   128, 1,   128, 128, 128, 2,    //
      0,   1,   128, 2,   128, 128, 128, 3,    //
      128, 128, 0,   1,   128, 128, 128, 2,    //
      0,   128, 1,   2,   128, 128, 128, 3,    //
      128, 0,   1,   2,   128, 128, 128, 3,    //
      0,   1,   2,   3,   128, 128, 128, 4,    //
      128, 128, 128, 128, 0,   128, 128, 1,    //
      0,   128, 128, 128, 1,   128, 128, 2,    //
      128, 0,   128, 128, 1,   128, 128, 2,    //
      0,   1,   128, 128, 2,   128, 128, 3,    //
      128, 128, 0,   128, 1,   128, 128, 2,    //
      0,   128, 1,   128, 2,   128, 128, 3,    //
      128, 0,   1,   128, 2,   128, 128, 3,    //
      0,   1,   2,   128, 3,   128, 128, 4,    //
      128, 128, 128, 0,   1,   128, 128, 2,    //
      0,   128, 128, 1,   2,   128, 128, 3,    //
      128, 0,   128, 1,   2,   128, 128, 3,    //
      0,   1,   128, 2,   3,   128, 128, 4,    //
      128, 128, 0,   1,   2,   128, 128, 3,    //
      0,   128, 1,   2,   3,   128, 128, 4,    //
      128, 0,   1,   2,   3,   128, 128, 4,    //
      0,   1,   2,   3,   4,   128, 128, 5,    //
      128, 128, 128, 128, 128, 0,   128, 1,    //
      0,   128, 128, 128, 128, 1,   128, 2,    //
      128, 0,   128, 128, 128, 1,   128, 2,    //
      0,   1,   128, 128, 128, 2,   128, 3,    //
      128, 128, 0,   128, 128, 1,   128, 2,    //
      0,   128, 1,   128, 128, 2,   128, 3,    //
      128, 0,   1,   128, 128, 2,   128, 3,    //
      0,   1,   2,   128, 128, 3,   128, 4,    //
      128, 128, 128, 0,   128, 1,   128, 2,    //
      0,   128, 128, 1,   128, 2,   128, 3,    //
      128, 0,   128, 1,   128, 2,   128, 3,    //
      0,   1,   128, 2,   128, 3,   128, 4,    //
      128, 128, 0,   1,   128, 2,   128, 3,    //
      0,   128, 1,   2,   128, 3,   128, 4,    //
      128, 0,   1,   2,   128, 3,   128, 4,    //
      0,   1,   2,   3,   128, 4,   128, 5,    //
      128, 128, 128, 128, 0,   1,   128, 2,    //
      0,   128, 128, 128, 1,   2,   128, 3,    //
      128, 0,   128, 128, 1,   2,   128, 3,    //
      0,   1,   128, 128, 2,   3,   128, 4,    //
      128, 128, 0,   128, 1,   2,   128, 3,    //
      0,   128, 1,   128, 2,   3,   128, 4,    //
      128, 0,   1,   128, 2,   3,   128, 4,    //
      0,   1,   2,   128, 3,   4,   128, 5,    //
      128, 128, 128, 0,   1,   2,   128, 3,    //
      0,   128, 128, 1,   2,   3,   128, 4,    //
      128, 0,   128, 1,   2,   3,   128, 4,    //
      0,   1,   128, 2,   3,   4,   128, 5,    //
      128, 128, 0,   1,   2,   3,   128, 4,    //
      0,   128, 1,   2,   3,   4,   128, 5,    //
      128, 0,   1,   2,   3,   4,   128, 5,    //
      0,   1,   2,   3,   4,   5,   128, 6,    //
      128, 128, 128, 128, 128, 128, 0,   1,    //
      0,   128, 128, 128, 128, 128, 1,   2,    //
      128, 0,   128, 128, 128, 128, 1,   2,    //
      0,   1,   128, 128, 128, 128, 2,   3,    //
      128, 128, 0,   128, 128, 128, 1,   2,    //
      0,   128, 1,   128, 128, 128, 2,   3,    //
      128, 0,   1,   128, 128, 128, 2,   3,    //
      0,   1,   2,   128, 128, 128, 3,   4,    //
      128, 128, 128, 0,   128, 128, 1,   2,    //
      0,   128, 128, 1,   128, 128, 2,   3,    //
      128, 0,   128, 1,   128, 128, 2,   3,    //
      0,   1,   128, 2,   128, 128, 3,   4,    //
      128, 128, 0,   1,   128, 128, 2,   3,    //
      0,   128, 1,   2,   128, 128, 3,   4,    //
      128, 0,   1,   2,   128, 128, 3,   4,    //
      0,   1,   2,   3,   128, 128, 4,   5,    //
      128, 128, 128, 128, 0,   128, 1,   2,    //
      0,   128, 128, 128, 1,   128, 2,   3,    //
      128, 0,   128, 128, 1,   128, 2,   3,    //
      0,   1,   128, 128, 2,   128, 3,   4,    //
      128, 128, 0,   128, 1,   128, 2,   3,    //
      0,   128, 1,   128, 2,   128, 3,   4,    //
      128, 0,   1,   128, 2,   128, 3,   4,    //
      0,   1,   2,   128, 3,   128, 4,   5,    //
      128, 128, 128, 0,   1,   128, 2,   3,    //
      0,   128, 128, 1,   2,   128, 3,   4,    //
      128, 0,   128, 1,   2,   128, 3,   4,    //
      0,   1,   128, 2,   3,   128, 4,   5,    //
      128, 128, 0,   1,   2,   128, 3,   4,    //
      0,   128, 1,   2,   3,   128, 4,   5,    //
      128, 0,   1,   2,   3,   128, 4,   5,    //
      0,   1,   2,   3,   4,   128, 5,   6,    //
      128, 128, 128, 128, 128, 0,   1,   2,    //
      0,   128, 128, 128, 128, 1,   2,   3,    //
      128, 0,   128, 128, 128, 1,   2,   3,    //
      0,   1,   128, 128, 128, 2,   3,   4,    //
      128, 128, 0,   128, 128, 1,   2,   3,    //
      0,   128, 1,   128, 128, 2,   3,   4,    //
      128, 0,   1,   128, 128, 2,   3,   4,    //
      0,   1,   2,   128, 128, 3,   4,   5,    //
      128, 128, 128, 0,   128, 1,   2,   3,    //
      0,   128, 128, 1,   128, 2,   3,   4,    //
      128, 0,   128, 1,   128, 2,   3,   4,    //
      0,   1,   128, 2,   128, 3,   4,   5,    //
      128, 128, 0,   1,   128, 2,   3,   4,    //
      0,   128, 1,   2,   128, 3,   4,   5,    //
      128, 0,   1,   2,   128, 3,   4,   5,    //
      0,   1,   2,   3,   128, 4,   5,   6,    //
      128, 128, 128, 128, 0,   1,   2,   3,    //
      0,   128, 128, 128, 1,   2,   3,   4,    //
      128, 0,   128, 128, 1,   2,   3,   4,    //
      0,   1,   128, 128, 2,   3,   4,   5,    //
      128, 128, 0,   128, 1,   2,   3,   4,    //
      0,   128, 1,   128, 2,   3,   4,   5,    //
      128, 0,   1,   128, 2,   3,   4,   5,    //
      0,   1,   2,   128, 3,   4,   5,   6,    //
      128, 128, 128, 0,   1,   2,   3,   4,    //
      0,   128, 128, 1,   2,   3,   4,   5,    //
      128, 0,   128, 1,   2,   3,   4,   5,    //
      0,   1,   128, 2,   3,   4,   5,   6,    //
      128, 128, 0,   1,   2,   3,   4,   5,    //
      0,   128, 1,   2,   3,   4,   5,   6,    //
      128, 0,   1,   2,   3,   4,   5,   6,    //
      0,   1,   2,   3,   4,   5,   6,   7};
  return LoadU(du8, table + mask_bits * 8);
}

}  // namespace detail

// Half vector of bytes: one table lookup
template <typename T, size_t N, HWY_IF_T_SIZE(T, 1), HWY_IF_V_SIZE_LE(T, N, 8)>
HWY_API Vec128<T, N> Expand(Vec128<T, N> v, Mask128<T, N> mask) {
  const DFromV<decltype(v)> d;

  const uint64_t mask_bits = detail::BitsFromMask(mask);
  const Vec128<uint8_t, N> indices =
      detail::IndicesForExpandFromBits<N>(mask_bits);
  return BitCast(d, TableLookupBytesOr0(v, indices));
}

// Full vector of bytes: two table lookups
template <typename T, HWY_IF_T_SIZE(T, 1)>
HWY_API Vec128<T> Expand(Vec128<T> v, Mask128<T> mask) {
  const Full128<T> d;
  const RebindToUnsigned<decltype(d)> du;
  const Half<decltype(du)> duh;
  const Vec128<uint8_t> vu = BitCast(du, v);

  const uint64_t mask_bits = detail::BitsFromMask(mask);
  const uint64_t maskL = mask_bits & 0xFF;
  const uint64_t maskH = mask_bits >> 8;

  // We want to skip past the v bytes already consumed by idxL. There is no
  // instruction for shift-reg by variable bytes. Storing v itself would work
  // but would involve a store-load forwarding stall. We instead shuffle using
  // loaded indices. multishift_epi64_epi8 would also help, but if we have that,
  // we probably also have native 8-bit Expand.
  alignas(16) static constexpr uint8_t iota[32] = {
      0,   1,   2,   3,   4,   5,   6,   7,   8,   9,   10,
      11,  12,  13,  14,  15,  128, 128, 128, 128, 128, 128,
      128, 128, 128, 128, 128, 128, 128, 128, 128, 128};
  const VFromD<decltype(du)> shift = LoadU(du, iota + PopCount(maskL));
  const VFromD<decltype(duh)> vL = LowerHalf(duh, vu);
  const VFromD<decltype(duh)> vH =
      LowerHalf(duh, TableLookupBytesOr0(vu, shift));

  const VFromD<decltype(duh)> idxL = detail::IndicesForExpandFromBits<8>(maskL);
  const VFromD<decltype(duh)> idxH = detail::IndicesForExpandFromBits<8>(maskH);

  const VFromD<decltype(duh)> expandL = TableLookupBytesOr0(vL, idxL);
  const VFromD<decltype(duh)> expandH = TableLookupBytesOr0(vH, idxH);
  return BitCast(d, Combine(du, expandH, expandL));
}

template <typename T, size_t N, HWY_IF_T_SIZE(T, 2)>
HWY_API Vec128<T, N> Expand(Vec128<T, N> v, Mask128<T, N> mask) {
  const DFromV<decltype(v)> d;
  const RebindToUnsigned<decltype(d)> du;

  const Rebind<uint8_t, decltype(d)> du8;
  const uint64_t mask_bits = detail::BitsFromMask(mask);

  // Storing as 8-bit reduces table size from 4 KiB to 2 KiB. We cannot apply
  // the nibble trick used below because not all indices fit within one lane.
  alignas(16) static constexpr uint8_t table[2048] = {
      // PrintExpand16x8ByteTables
      128, 128, 128, 128, 128, 128, 128, 128,  //
      0,   128, 128, 128, 128, 128, 128, 128,  //
      128, 0,   128, 128, 128, 128, 128, 128,  //
      0,   2,   128, 128, 128, 128, 128, 128,  //
      128, 128, 0,   128, 128, 128, 128, 128,  //
      0,   128, 2,   128, 128, 128, 128, 128,  //
      128, 0,   2,   128, 128, 128, 128, 128,  //
      0,   2,   4,   128, 128, 128, 128, 128,  //
      128, 128, 128, 0,   128, 128, 128, 128,  //
      0,   128, 128, 2,   128, 128, 128, 128,  //
      128, 0,   128, 2,   128, 128, 128, 128,  //
      0,   2,   128, 4,   128, 128, 128, 128,  //
      128, 128, 0,   2,   128, 128, 128, 128,  //
      0,   128, 2,   4,   128, 128, 128, 128,  //
      128, 0,   2,   4,   128, 128, 128, 128,  //
      0,   2,   4,   6,   128, 128, 128, 128,  //
      128, 128, 128, 128, 0,   128, 128, 128,  //
      0,   128, 128, 128, 2,   128, 128, 128,  //
      128, 0,   128, 128, 2,   128, 128, 128,  //
      0,   2,   128, 128, 4,   128, 128, 128,  //
      128, 128, 0,   128, 2,   128, 128, 128,  //
      0,   128, 2,   128, 4,   128, 128, 128,  //
      128, 0,   2,   128, 4,   128, 128, 128,  //
      0,   2,   4,   128, 6,   128, 128, 128,  //
      128, 128, 128, 0,   2,   128, 128, 128,  //
      0,   128, 128, 2,   4,   128, 128, 128,  //
      128, 0,   128, 2,   4,   128, 128, 128,  //
      0,   2,   128, 4,   6,   128, 128, 128,  //
      128, 128, 0,   2,   4,   128, 128, 128,  //
      0,   128, 2,   4,   6,   128, 128, 128,  //
      128, 0,   2,   4,   6,   128, 128, 128,  //
      0,   2,   4,   6,   8,   128, 128, 128,  //
      128, 128, 128, 128, 128, 0,   128, 128,  //
      0,   128, 128, 128, 128, 2,   128, 128,  //
      128, 0,   128, 128, 128, 2,   128, 128,  //
      0,   2,   128, 128, 128, 4,   128, 128,  //
      128, 128, 0,   128, 128, 2,   128, 128,  //
      0,   128, 2,   128, 128, 4,   128, 128,  //
      128, 0,   2,   128, 128, 4,   128, 128,  //
      0,   2,   4,   128, 128, 6,   128, 128,  //
      128, 128, 128, 0,   128, 2,   128, 128,  //
      0,   128, 128, 2,   128, 4,   128, 128,  //
      128, 0,   128, 2,   128, 4,   128, 128,  //
      0,   2,   128, 4,   128, 6,   128, 128,  //
      128, 128, 0,   2,   128, 4,   128, 128,  //
      0,   128, 2,   4,   128, 6,   128, 128,  //
      128, 0,   2,   4,   128, 6,   128, 128,  //
      0,   2,   4,   6,   128, 8,   128, 128,  //
      128, 128, 128, 128, 0,   2,   128, 128,  //
      0,   128, 128, 128, 2,   4,   128, 128,  //
      128, 0,   128, 128, 2,   4,   128, 128,  //
      0,   2,   128, 128, 4,   6,   128, 128,  //
      128, 128, 0,   128, 2,   4,   128, 128,  //
      0,   128, 2,   128, 4,   6,   128, 128,  //
      128, 0,   2,   128, 4,   6,   128, 128,  //
      0,   2,   4,   128, 6,   8,   128, 128,  //
      128, 128, 128, 0,   2,   4,   128, 128,  //
      0,   128, 128, 2,   4,   6,   128, 128,  //
      128, 0,   128, 2,   4,   6,   128, 128,  //
      0,   2,   128, 4,   6,   8,   128, 128,  //
      128, 128, 0,   2,   4,   6,   128, 128,  //
      0,   128, 2,   4,   6,   8,   128, 128,  //
      128, 0,   2,   4,   6,   8,   128, 128,  //
      0,   2,   4,   6,   8,   10,  128, 128,  //
      128, 128, 128, 128, 128, 128, 0,   128,  //
      0,   128, 128, 128, 128, 128, 2,   128,  //
      128, 0,   128, 128, 128, 128, 2,   128,  //
      0,   2,   128, 128, 128, 128, 4,   128,  //
      128, 128, 0,   128, 128, 128, 2,   128,  //
      0,   128, 2,   128, 128, 128, 4,   128,  //
      128, 0,   2,   128, 128, 128, 4,   128,  //
      0,   2,   4,   128, 128, 128, 6,   128,  //
      128, 128, 128, 0,   128, 128, 2,   128,  //
      0,   128, 128, 2,   128, 128, 4,   128,  //
      128, 0,   128, 2,   128, 128, 4,   128,  //
      0,   2,   128, 4,   128, 128, 6,   128,  //
      128, 128, 0,   2,   128, 128, 4,   128,  //
      0,   128, 2,   4,   128, 128, 6,   128,  //
      128, 0,   2,   4,   128, 128, 6,   128,  //
      0,   2,   4,   6,   128, 128, 8,   128,  //
      128, 128, 128, 128, 0,   128, 2,   128,  //
      0,   128, 128, 128, 2,   128, 4,   128,  //
      128, 0,   128, 128, 2,   128, 4,   128,  //
      0,   2,   128, 128, 4,   128, 6,   128,  //
      128, 128, 0,   128, 2,   128, 4,   128,  //
      0,   128, 2,   128, 4,   128, 6,   128,  //
      128, 0,   2,   128, 4,   128, 6,   128,  //
      0,   2,   4,   128, 6,   128, 8,   128,  //
      128, 128, 128, 0,   2,   128, 4,   128,  //
      0,   128, 128, 2,   4,   128, 6,   128,  //
      128, 0,   128, 2,   4,   128, 6,   128,  //
      0,   2,   128, 4,   6,   128, 8,   128,  //
      128, 128, 0,   2,   4,   128, 6,   128,  //
      0,   128, 2,   4,   6,   128, 8,   128,  //
      128, 0,   2,   4,   6,   128, 8,   128,  //
      0,   2,   4,   6,   8,   128, 10,  128,  //
      128, 128, 128, 128, 128, 0,   2,   128,  //
      0,   128, 128, 128, 128, 2,   4,   128,  //
      128, 0,   128, 128, 128, 2,   4,   128,  //
      0,   2,   128, 128, 128, 4,   6,   128,  //
      128, 128, 0,   128, 128, 2,   4,   128,  //
      0,   128, 2,   128, 128, 4,   6,   128,  //
      128, 0,   2,   128, 128, 4,   6,   128,  //
      0,   2,   4,   128, 128, 6,   8,   128,  //
      128, 128, 128, 0,   128, 2,   4,   128,  //
      0,   128, 128, 2,   128, 4,   6,   128,  //
      128, 0,   128, 2,   128, 4,   6,   128,  //
      0,   2,   128, 4,   128, 6,   8,   128,  //
      128, 128, 0,   2,   128, 4,   6,   128,  //
      0,   128, 2,   4,   128, 6,   8,   128,  //
      128, 0,   2,   4,   128, 6,   8,   128,  //
      0,   2,   4,   6,   128, 8,   10,  128,  //
      128, 128, 128, 128, 0,   2,   4,   128,  //
      0,   128, 128, 128, 2,   4,   6,   128,  //
      128, 0,   128, 128, 2,   4,   6,   128,  //
      0,   2,   128, 128, 4,   6,   8,   128,  //
      128, 128, 0,   128, 2,   4,   6,   128,  //
      0,   128, 2,   128, 4,   6,   8,   128,  //
      128, 0,   2,   128, 4,   6,   8,   128,  //
      0,   2,   4,   128, 6,   8,   10,  128,  //
      128, 128, 128, 0,   2,   4,   6,   128,  //
      0,   128, 128, 2,   4,   6,   8,   128,  //
      128, 0,   128, 2,   4,   6,   8,   128,  //
      0,   2,   128, 4,   6,   8,   10,  128,  //
      128, 128, 0,   2,   4,   6,   8,   128,  //
      0,   128, 2,   4,   6,   8,   10,  128,  //
      128, 0,   2,   4,   6,   8,   10,  128,  //
      0,   2,   4,   6,   8,   10,  12,  128,  //
      128, 128, 128, 128, 128, 128, 128, 0,    //
      0,   128, 128, 128, 128, 128, 128, 2,    //
      128, 0,   128, 128, 128, 128, 128, 2,    //
      0,   2,   128, 128, 128, 128, 128, 4,    //
      128, 128, 0,   128, 128, 128, 128, 2,    //
      0,   128, 2,   128, 128, 128, 128, 4,    //
      128, 0,   2,   128, 128, 128, 128, 4,    //
      0,   2,   4,   128, 128, 128, 128, 6,    //
      128, 128, 128, 0,   128, 128, 128, 2,    //
      0,   128, 128, 2,   128, 128, 128, 4,    //
      128, 0,   128, 2,   128, 128, 128, 4,    //
      0,   2,   128, 4,   128, 128, 128, 6,    //
      128, 128, 0,   2,   128, 128, 128, 4,    //
      0,   128, 2,   4,   128, 128, 128, 6,    //
      128, 0,   2,   4,   128, 128, 128, 6,    //
      0,   2,   4,   6,   128, 128, 128, 8,    //
      128, 128, 128, 128, 0,   128, 128, 2,    //
      0,   128, 128, 128, 2,   128, 128, 4,    //
      128, 0,   128, 128, 2,   128, 128, 4,    //
      0,   2,   128, 128, 4,   128, 128, 6,    //
      128, 128, 0,   128, 2,   128, 128, 4,    //
      0,   128, 2,   128, 4,   128, 128, 6,    //
      128, 0,   2,   128, 4,   128, 128, 6,    //
      0,   2,   4,   128, 6,   128, 128, 8,    //
      128, 128, 128, 0,   2,   128, 128, 4,    //
      0,   128, 128, 2,   4,   128, 128, 6,    //
      128, 0,   128, 2,   4,   128, 128, 6,    //
      0,   2,   128, 4,   6,   128, 128, 8,    //
      128, 128, 0,   2,   4,   128, 128, 6,    //
      0,   128, 2,   4,   6,   128, 128, 8,    //
      128, 0,   2,   4,   6,   128, 128, 8,    //
      0,   2,   4,   6,   8,   128, 128, 10,   //
      128, 128, 128, 128, 128, 0,   128, 2,    //
      0,   128, 128, 128, 128, 2,   128, 4,    //
      128, 0,   128, 128, 128, 2,   128, 4,    //
      0,   2,   128, 128, 128, 4,   128, 6,    //
      128, 128, 0,   128, 128, 2,   128, 4,    //
      0,   128, 2,   128, 128, 4,   128, 6,    //
      128, 0,   2,   128, 128, 4,   128, 6,    //
      0,   2,   4,   128, 128, 6,   128, 8,    //
      128, 128, 128, 0,   128, 2,   128, 4,    //
      0,   128, 128, 2,   128, 4,   128, 6,    //
      128, 0,   128, 2,   128, 4,   128, 6,    //
      0,   2,   128, 4,   128, 6,   128, 8,    //
      128, 128, 0,   2,   128, 4,   128, 6,    //
      0,   128, 2,   4,   128, 6,   128, 8,    //
      128, 0,   2,   4,   128, 6,   128, 8,    //
      0,   2,   4,   6,   128, 8,   128, 10,   //
      128, 128, 128, 128, 0,   2,   128, 4,    //
      0,   128, 128, 128, 2,   4,   128, 6,    //
      128, 0,   128, 128, 2,   4,   128, 6,    //
      0,   2,   128, 128, 4,   6,   128, 8,    //
      128, 128, 0,   128, 2,   4,   128, 6,    //
      0,   128, 2,   128, 4,   6,   128, 8,    //
      128, 0,   2,   128, 4,   6,   128, 8,    //
      0,   2,   4,   128, 6,   8,   128, 10,   //
      128, 128, 128, 0,   2,   4,   128, 6,    //
      0,   128, 128, 2,   4,   6,   128, 8,    //
      128, 0,   128, 2,   4,   6,   128, 8,    //
      0,   2,   128, 4,   6,   8,   128, 10,   //
      128, 128, 0,   2,   4,   6,   128, 8,    //
      0,   128, 2,   4,   6,   8,   128, 10,   //
      128, 0,   2,   4,   6,   8,   128, 10,   //
      0,   2,   4,   6,   8,   10,  128, 12,   //
      128, 128, 128, 128, 128, 128, 0,   2,    //
      0,   128, 128, 128, 128, 128, 2,   4,    //
      128, 0,   128, 128, 128, 128, 2,   4,    //
      0,   2,   128, 128, 128, 128, 4,   6,    //
      128, 128, 0,   128, 128, 128, 2,   4,    //
      0,   128, 2,   128, 128, 128, 4,   6,    //
      128, 0,   2,   128, 128, 128, 4,   6,    //
      0,   2,   4,   128, 128, 128, 6,   8,    //
      128, 128, 128, 0,   128, 128, 2,   4,    //
      0,   128, 128, 2,   128, 128, 4,   6,    //
      128, 0,   128, 2,   128, 128, 4,   6,    //
      0,   2,   128, 4,   128, 128, 6,   8,    //
      128, 128, 0,   2,   128, 128, 4,   6,    //
      0,   128, 2,   4,   128, 128, 6,   8,    //
      128, 0,   2,   4,   128, 128, 6,   8,    //
      0,   2,   4,   6,   128, 128, 8,   10,   //
      128, 128, 128, 128, 0,   128, 2,   4,    //
      0,   128, 128, 128, 2,   128, 4,   6,    //
      128, 0,   128, 128, 2,   128, 4,   6,    //
      0,   2,   128, 128, 4,   128, 6,   8,    //
      128, 128, 0,   128, 2,   128, 4,   6,    //
      0,   128, 2,   128, 4,   128, 6,   8,    //
      128, 0,   2,   128, 4,   128, 6,   8,    //
      0,   2,   4,   128, 6,   128, 8,   10,   //
      128, 128, 128, 0,   2,   128, 4,   6,    //
      0,   128, 128, 2,   4,   128, 6,   8,    //
      128, 0,   128, 2,   4,   128, 6,   8,    //
      0,   2,   128, 4,   6,   128, 8,   10,   //
      128, 128, 0,   2,   4,   128, 6,   8,    //
      0,   128, 2,   4,   6,   128, 8,   10,   //
      128, 0,   2,   4,   6,   128, 8,   10,   //
      0,   2,   4,   6,   8,   128, 10,  12,   //
      128, 128, 128, 128, 128, 0,   2,   4,    //
      0,   128, 128, 128, 128, 2,   4,   6,    //
      128, 0,   128, 128, 128, 2,   4,   6,    //
      0,   2,   128, 128, 128, 4,   6,   8,    //
      128, 128, 0,   128, 128, 2,   4,   6,    //
      0,   128, 2,   128, 128, 4,   6,   8,    //
      128, 0,   2,   128, 128, 4,   6,   8,    //
      0,   2,   4,   128, 128, 6,   8,   10,   //
      128, 128, 128, 0,   128, 2,   4,   6,    //
      0,   128, 128, 2,   128, 4,   6,   8,    //
      128, 0,   128, 2,   128, 4,   6,   8,    //
      0,   2,   128, 4,   128, 6,   8,   10,   //
      128, 128, 0,   2,   128, 4,   6,   8,    //
      0,   128, 2,   4,   128, 6,   8,   10,   //
      128, 0,   2,   4,   128, 6,   8,   10,   //
      0,   2,   4,   6,   128, 8,   10,  12,   //
      128, 128, 128, 128, 0,   2,   4,   6,    //
      0,   128, 128, 128, 2,   4,   6,   8,    //
      128, 0,   128, 128, 2,   4,   6,   8,    //
      0,   2,   128, 128, 4,   6,   8,   10,   //
      128, 128, 0,   128, 2,   4,   6,   8,    //
      0,   128, 2,   128, 4,   6,   8,   10,   //
      128, 0,   2,   128, 4,   6,   8,   10,   //
      0,   2,   4,   128, 6,   8,   10,  12,   //
      128, 128, 128, 0,   2,   4,   6,   8,    //
      0,   128, 128, 2,   4,   6,   8,   10,   //
      128, 0,   128, 2,   4,   6,   8,   10,   //
      0,   2,   128, 4,   6,   8,   10,  12,   //
      128, 128, 0,   2,   4,   6,   8,   10,   //
      0,   128, 2,   4,   6,   8,   10,  12,   //
      128, 0,   2,   4,   6,   8,   10,  12,   //
      0,   2,   4,   6,   8,   10,  12,  14};
  // Extend to double length because InterleaveLower will only use the (valid)
  // lower half, and we want N u16.
  const Twice<decltype(du8)> du8x2;
  const Vec128<uint8_t, 2 * N> indices8 =
      ZeroExtendVector(du8x2, Load(du8, table + mask_bits * 8));
  const Vec128<uint16_t, N> indices16 =
      BitCast(du, InterleaveLower(du8x2, indices8, indices8));
  // TableLookupBytesOr0 operates on bytes. To convert u16 lane indices to byte
  // indices, add 0 to even and 1 to odd byte lanes.
  const Vec128<uint16_t, N> byte_indices = Add(indices16, Set(du, 0x0100));
  return BitCast(d, TableLookupBytesOr0(v, byte_indices));
}

template <typename T, size_t N, HWY_IF_T_SIZE(T, 4)>
HWY_API Vec128<T, N> Expand(Vec128<T, N> v, Mask128<T, N> mask) {
  const DFromV<decltype(v)> d;
  const RebindToUnsigned<decltype(d)> du;

  const uint64_t mask_bits = detail::BitsFromMask(mask);

  alignas(16) static constexpr uint32_t packed_array[16] = {
      // PrintExpand64x4Nibble - same for 32x4.
      0x0000ffff, 0x0000fff0, 0x0000ff0f, 0x0000ff10, 0x0000f0ff, 0x0000f1f0,
      0x0000f10f, 0x0000f210, 0x00000fff, 0x00001ff0, 0x00001f0f, 0x00002f10,
      0x000010ff, 0x000021f0, 0x0000210f, 0x00003210};

  // For lane i, shift the i-th 4-bit index down to bits [0, 2).
  const Vec128<uint32_t, N> packed = Set(du, packed_array[mask_bits]);
  alignas(16) static constexpr uint32_t shifts[4] = {0, 4, 8, 12};
  Vec128<uint32_t, N> indices = packed >> Load(du, shifts);
  // AVX2 _mm256_permutexvar_epi32 will ignore upper bits, but IndicesFromVec
  // checks bounds, so clear the upper bits.
  indices = And(indices, Set(du, N - 1));
  const Vec128<uint32_t, N> expand =
      TableLookupLanes(BitCast(du, v), IndicesFromVec(du, indices));
  // TableLookupLanes cannot also zero masked-off lanes, so do that now.
  return IfThenElseZero(mask, BitCast(d, expand));
}

template <typename T, HWY_IF_T_SIZE(T, 8)>
HWY_API Vec128<T> Expand(Vec128<T> v, Mask128<T> mask) {
  // Same as Compress, just zero out the mask=false lanes.
  return IfThenElseZero(mask, Compress(v, mask));
}

// For single-element vectors, this is at least as fast as native.
template <typename T>
HWY_API Vec128<T, 1> Expand(Vec128<T, 1> v, Mask128<T, 1> mask) {
  return IfThenElseZero(mask, v);
}

// ------------------------------ LoadExpand
template <class D, HWY_IF_V_SIZE_LE_D(D, 16)>
HWY_API VFromD<D> LoadExpand(MFromD<D> mask, D d,
                             const TFromD<D>* HWY_RESTRICT unaligned) {
  return Expand(LoadU(d, unaligned), mask);
}

#endif  // HWY_NATIVE_EXPAND

// ------------------------------ TwoTablesLookupLanes

template <class D>
using IndicesFromD = decltype(IndicesFromVec(D(), Zero(RebindToUnsigned<D>())));

// RVV/SVE have their own implementations of
// TwoTablesLookupLanes(D d, VFromD<D> a, VFromD<D> b, IndicesFromD<D> idx)
#if HWY_TARGET != HWY_RVV && HWY_TARGET != HWY_SVE &&      \
    HWY_TARGET != HWY_SVE2 && HWY_TARGET != HWY_SVE_256 && \
    HWY_TARGET != HWY_SVE2_128
template <class D>
HWY_API VFromD<D> TwoTablesLookupLanes(D /*d*/, VFromD<D> a, VFromD<D> b,
                                       IndicesFromD<D> idx) {
  return TwoTablesLookupLanes(a, b, idx);
}
#endif

// ------------------------------ Reverse2, Reverse4, Reverse8 (8-bit)

#if (defined(HWY_NATIVE_REVERSE2_8) == defined(HWY_TARGET_TOGGLE)) || HWY_IDE
#ifdef HWY_NATIVE_REVERSE2_8
#undef HWY_NATIVE_REVERSE2_8
#else
#define HWY_NATIVE_REVERSE2_8
#endif

#undef HWY_PREFER_ROTATE
// Platforms on which RotateRight is likely faster than TableLookupBytes.
// RVV and SVE anyway have their own implementation of this.
#if HWY_TARGET == HWY_SSE2 || HWY_TARGET <= HWY_AVX3 || \
    HWY_TARGET == HWY_WASM || HWY_TARGET == HWY_PPC8
#define HWY_PREFER_ROTATE 1
#else
#define HWY_PREFER_ROTATE 0
#endif

template <class D, HWY_IF_T_SIZE_D(D, 1)>
HWY_API VFromD<D> Reverse2(D d, VFromD<D> v) {
  // Exclude AVX3 because its 16-bit RotateRight is actually 3 instructions.
#if HWY_PREFER_ROTATE && HWY_TARGET > HWY_AVX3
  const Repartition<uint16_t, decltype(d)> du16;
  return BitCast(d, RotateRight<8>(BitCast(du16, v)));
#else
  alignas(16) static constexpr TFromD<D> kShuffle[16] = {
      1, 0, 3, 2, 5, 4, 7, 6, 9, 8, 11, 10, 13, 12, 15, 14};
  return TableLookupBytes(v, LoadDup128(d, kShuffle));
#endif
}

template <class D, HWY_IF_T_SIZE_D(D, 1)>
HWY_API VFromD<D> Reverse4(D d, VFromD<D> v) {
#if HWY_PREFER_ROTATE
  const Repartition<uint16_t, decltype(d)> du16;
  return BitCast(d, Reverse2(du16, BitCast(du16, Reverse2(d, v))));
#else
  alignas(16) static constexpr uint8_t kShuffle[16] = {
      3, 2, 1, 0, 7, 6, 5, 4, 11, 10, 9, 8, 15, 14, 13, 12};
  const Repartition<uint8_t, decltype(d)> du8;
  return TableLookupBytes(v, BitCast(d, LoadDup128(du8, kShuffle)));
#endif
}

template <class D, HWY_IF_T_SIZE_D(D, 1)>
HWY_API VFromD<D> Reverse8(D d, VFromD<D> v) {
#if HWY_PREFER_ROTATE
  const Repartition<uint32_t, D> du32;
  return BitCast(d, Reverse2(du32, BitCast(du32, Reverse4(d, v))));
#else
  alignas(16) static constexpr uint8_t kShuffle[16] = {
      7, 6, 5, 4, 3, 2, 1, 0, 15, 14, 13, 12, 11, 10, 9, 8};
  const Repartition<uint8_t, decltype(d)> du8;
  return TableLookupBytes(v, BitCast(d, LoadDup128(du8, kShuffle)));
#endif
}

#endif  // HWY_NATIVE_REVERSE2_8

// ------------------------------ ReverseLaneBytes

#if (defined(HWY_NATIVE_REVERSE_LANE_BYTES) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_REVERSE_LANE_BYTES
#undef HWY_NATIVE_REVERSE_LANE_BYTES
#else
#define HWY_NATIVE_REVERSE_LANE_BYTES
#endif

template <class V, HWY_IF_T_SIZE_V(V, 2)>
HWY_API V ReverseLaneBytes(V v) {
  const DFromV<V> d;
  const Repartition<uint8_t, decltype(d)> du8;
  return BitCast(d, Reverse2(du8, BitCast(du8, v)));
}

template <class V, HWY_IF_T_SIZE_V(V, 4)>
HWY_API V ReverseLaneBytes(V v) {
  const DFromV<V> d;
  const Repartition<uint8_t, decltype(d)> du8;
  return BitCast(d, Reverse4(du8, BitCast(du8, v)));
}

template <class V, HWY_IF_T_SIZE_V(V, 8)>
HWY_API V ReverseLaneBytes(V v) {
  const DFromV<V> d;
  const Repartition<uint8_t, decltype(d)> du8;
  return BitCast(d, Reverse8(du8, BitCast(du8, v)));
}

#endif  // HWY_NATIVE_REVERSE_LANE_BYTES

// ------------------------------ ReverseBits

// On these targets, we emulate 8-bit shifts using 16-bit shifts and therefore
// require at least two lanes to BitCast to 16-bit. We avoid Highway's 8-bit
// shifts because those would add extra masking already taken care of by
// UI8ReverseBitsStep. Note that AVX3_DL/AVX3_ZEN4 support GFNI and use it to
// implement ReverseBits, so this code is not used there.
#undef HWY_REVERSE_BITS_MIN_BYTES
#if ((HWY_TARGET >= HWY_AVX3 && HWY_TARGET <= HWY_SSE2) || \
     HWY_TARGET == HWY_WASM || HWY_TARGET == HWY_WASM_EMU256)
#define HWY_REVERSE_BITS_MIN_BYTES 2
#else
#define HWY_REVERSE_BITS_MIN_BYTES 1
#endif

#if (defined(HWY_NATIVE_REVERSE_BITS_UI8) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_REVERSE_BITS_UI8
#undef HWY_NATIVE_REVERSE_BITS_UI8
#else
#define HWY_NATIVE_REVERSE_BITS_UI8
#endif

namespace detail {

template <int kShiftAmt, int kShrResultMask, class V,
          HWY_IF_V_SIZE_GT_D(DFromV<V>, HWY_REVERSE_BITS_MIN_BYTES - 1)>
HWY_INLINE V UI8ReverseBitsStep(V v) {
  const DFromV<decltype(v)> d;
  const RebindToUnsigned<decltype(d)> du;
#if HWY_REVERSE_BITS_MIN_BYTES == 2
  const Repartition<uint16_t, decltype(d)> d_shift;
#else
  const RebindToUnsigned<decltype(d)> d_shift;
#endif

  const auto v_to_shift = BitCast(d_shift, v);
  const auto shl_result = BitCast(d, ShiftLeft<kShiftAmt>(v_to_shift));
  const auto shr_result = BitCast(d, ShiftRight<kShiftAmt>(v_to_shift));
  const auto shr_result_mask =
      BitCast(d, Set(du, static_cast<uint8_t>(kShrResultMask)));
  return Or(And(shr_result, shr_result_mask),
            AndNot(shr_result_mask, shl_result));
}

#if HWY_REVERSE_BITS_MIN_BYTES == 2
template <int kShiftAmt, int kShrResultMask, class V,
          HWY_IF_V_SIZE_D(DFromV<V>, 1)>
HWY_INLINE V UI8ReverseBitsStep(V v) {
  return V{UI8ReverseBitsStep<kShiftAmt, kShrResultMask>(Vec128<uint8_t>{v.raw})
               .raw};
}
#endif

}  // namespace detail

template <class V, HWY_IF_T_SIZE_V(V, 1)>
HWY_API V ReverseBits(V v) {
  auto result = detail::UI8ReverseBitsStep<1, 0x55>(v);
  result = detail::UI8ReverseBitsStep<2, 0x33>(result);
  result = detail::UI8ReverseBitsStep<4, 0x0F>(result);
  return result;
}

#endif  // HWY_NATIVE_REVERSE_BITS_UI8

#if (defined(HWY_NATIVE_REVERSE_BITS_UI16_32_64) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_REVERSE_BITS_UI16_32_64
#undef HWY_NATIVE_REVERSE_BITS_UI16_32_64
#else
#define HWY_NATIVE_REVERSE_BITS_UI16_32_64
#endif

template <class V, HWY_IF_T_SIZE_ONE_OF_V(V, (1 << 2) | (1 << 4) | (1 << 8)),
          HWY_IF_NOT_FLOAT_NOR_SPECIAL_V(V)>
HWY_API V ReverseBits(V v) {
  const DFromV<decltype(v)> d;
  const Repartition<uint8_t, decltype(d)> du8;
  return ReverseLaneBytes(BitCast(d, ReverseBits(BitCast(du8, v))));
}
#endif  // HWY_NATIVE_REVERSE_BITS_UI16_32_64

// ------------------------------ Per4LaneBlockShuffle

#if (defined(HWY_NATIVE_PER4LANEBLKSHUF_DUP32) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_PER4LANEBLKSHUF_DUP32
#undef HWY_NATIVE_PER4LANEBLKSHUF_DUP32
#else
#define HWY_NATIVE_PER4LANEBLKSHUF_DUP32
#endif

#if HWY_TARGET != HWY_SCALAR
namespace detail {

template <class D>
HWY_INLINE Vec<D> Per4LaneBlkShufDupSet4xU32(D d, const uint32_t x3,
                                             const uint32_t x2,
                                             const uint32_t x1,
                                             const uint32_t x0) {
  alignas(16) const uint32_t lanes[4] = {x0, x1, x2, x3};

#if HWY_TARGET == HWY_RVV
  constexpr int kPow2 = d.Pow2();
  constexpr int kLoadPow2 = HWY_MAX(kPow2, -1);
  const ScalableTag<uint32_t, kLoadPow2> d_load;
#else
  constexpr size_t kMaxBytes = d.MaxBytes();
#if HWY_TARGET == HWY_NEON || HWY_TARGET == HWY_NEON_WITHOUT_AES
  constexpr size_t kMinLanesToLoad = 2;
#else
  constexpr size_t kMinLanesToLoad = 4;
#endif
  constexpr size_t kNumToLoad =
      HWY_MAX(kMaxBytes / sizeof(uint32_t), kMinLanesToLoad);
  const CappedTag<uint32_t, kNumToLoad> d_load;
#endif

  return ResizeBitCast(d, LoadDup128(d_load, lanes));
}

}  // namespace detail
#endif

#endif  // HWY_NATIVE_PER4LANEBLKSHUF_DUP32

#if HWY_TARGET != HWY_SCALAR
namespace detail {

template <class V>
HWY_INLINE V Per2LaneBlockShuffle(hwy::SizeTag<0> /*idx_10_tag*/, V v) {
  return DupEven(v);
}

template <class V>
HWY_INLINE V Per2LaneBlockShuffle(hwy::SizeTag<1> /*idx_10_tag*/, V v) {
  const DFromV<decltype(v)> d;
  return Reverse2(d, v);
}

template <class V>
HWY_INLINE V Per2LaneBlockShuffle(hwy::SizeTag<2> /*idx_10_tag*/, V v) {
  return v;
}

template <class V>
HWY_INLINE V Per2LaneBlockShuffle(hwy::SizeTag<3> /*idx_10_tag*/, V v) {
  return DupOdd(v);
}

HWY_INLINE uint32_t U8x4Per4LaneBlkIndices(const uint32_t idx3,
                                           const uint32_t idx2,
                                           const uint32_t idx1,
                                           const uint32_t idx0) {
#if HWY_IS_LITTLE_ENDIAN
  return static_cast<uint32_t>((idx3 << 24) | (idx2 << 16) | (idx1 << 8) |
                               idx0);
#else
  return static_cast<uint32_t>(idx3 | (idx2 << 8) | (idx1 << 16) |
                               (idx0 << 24));
#endif
}

template <class D>
HWY_INLINE Vec<D> TblLookupPer4LaneBlkU8IdxInBlk(D d, const uint32_t idx3,
                                                 const uint32_t idx2,
                                                 const uint32_t idx1,
                                                 const uint32_t idx0) {
#if HWY_TARGET == HWY_RVV
  const AdjustSimdTagToMinVecPow2<Repartition<uint32_t, D>> du32;
#else
  const Repartition<uint32_t, D> du32;
#endif

  return ResizeBitCast(
      d, Set(du32, U8x4Per4LaneBlkIndices(idx3, idx2, idx1, idx0)));
}

#if HWY_HAVE_SCALABLE || HWY_TARGET == HWY_SVE_256 || \
    HWY_TARGET == HWY_SVE2_128 || HWY_TARGET == HWY_EMU128
#define HWY_PER_4_BLK_TBL_LOOKUP_LANES_ENABLE(D) void* = nullptr
#else
#define HWY_PER_4_BLK_TBL_LOOKUP_LANES_ENABLE(D) HWY_IF_T_SIZE_D(D, 8)

template <class V, HWY_IF_T_SIZE_ONE_OF_V(V, (1 << 1) | (1 << 2) | (1 << 4))>
HWY_INLINE V Per4LaneBlkShufDoTblLookup(V v, V idx) {
  const DFromV<decltype(v)> d;
  const Repartition<uint8_t, decltype(d)> du8;
  return BitCast(d, TableLookupBytes(BitCast(du8, v), BitCast(du8, idx)));
}

template <class D, HWY_IF_T_SIZE_D(D, 1)>
HWY_INLINE Vec<D> TblLookupPer4LaneBlkShufIdx(D d, const uint32_t idx3,
                                              const uint32_t idx2,
                                              const uint32_t idx1,
                                              const uint32_t idx0) {
  const Repartition<uint32_t, decltype(d)> du32;
  const uint32_t idx3210 = U8x4Per4LaneBlkIndices(idx3, idx2, idx1, idx0);
  const auto v_byte_idx = Per4LaneBlkShufDupSet4xU32(
      du32, static_cast<uint32_t>(idx3210 + 0x0C0C0C0C),
      static_cast<uint32_t>(idx3210 + 0x08080808),
      static_cast<uint32_t>(idx3210 + 0x04040404),
      static_cast<uint32_t>(idx3210));
  return ResizeBitCast(d, v_byte_idx);
}

template <class D, HWY_IF_T_SIZE_D(D, 2)>
HWY_INLINE Vec<D> TblLookupPer4LaneBlkShufIdx(D d, const uint32_t idx3,
                                              const uint32_t idx2,
                                              const uint32_t idx1,
                                              const uint32_t idx0) {
  const Repartition<uint32_t, decltype(d)> du32;
#if HWY_IS_LITTLE_ENDIAN
  const uint32_t idx10 = static_cast<uint32_t>((idx1 << 16) | idx0);
  const uint32_t idx32 = static_cast<uint32_t>((idx3 << 16) | idx2);
  constexpr uint32_t kLaneByteOffsets{0x01000100};
#else
  const uint32_t idx10 = static_cast<uint32_t>(idx1 | (idx0 << 16));
  const uint32_t idx32 = static_cast<uint32_t>(idx3 | (idx2 << 16));
  constexpr uint32_t kLaneByteOffsets{0x00010001};
#endif
  constexpr uint32_t kHiLaneByteOffsets{kLaneByteOffsets + 0x08080808u};

  const auto v_byte_idx = Per4LaneBlkShufDupSet4xU32(
      du32, static_cast<uint32_t>(idx32 * 0x0202u + kHiLaneByteOffsets),
      static_cast<uint32_t>(idx10 * 0x0202u + kHiLaneByteOffsets),
      static_cast<uint32_t>(idx32 * 0x0202u + kLaneByteOffsets),
      static_cast<uint32_t>(idx10 * 0x0202u + kLaneByteOffsets));
  return ResizeBitCast(d, v_byte_idx);
}

template <class D, HWY_IF_T_SIZE_D(D, 4)>
HWY_INLINE Vec<D> TblLookupPer4LaneBlkShufIdx(D d, const uint32_t idx3,
                                              const uint32_t idx2,
                                              const uint32_t idx1,
                                              const uint32_t idx0) {
  const Repartition<uint32_t, decltype(d)> du32;
#if HWY_IS_LITTLE_ENDIAN
  constexpr uint32_t kLaneByteOffsets{0x03020100};
#else
  constexpr uint32_t kLaneByteOffsets{0x00010203};
#endif

  const auto v_byte_idx = Per4LaneBlkShufDupSet4xU32(
      du32, static_cast<uint32_t>(idx3 * 0x04040404u + kLaneByteOffsets),
      static_cast<uint32_t>(idx2 * 0x04040404u + kLaneByteOffsets),
      static_cast<uint32_t>(idx1 * 0x04040404u + kLaneByteOffsets),
      static_cast<uint32_t>(idx0 * 0x04040404u + kLaneByteOffsets));
  return ResizeBitCast(d, v_byte_idx);
}
#endif

template <class D, HWY_IF_T_SIZE_D(D, 1)>
HWY_INLINE VFromD<D> TblLookupPer4LaneBlkIdxInBlk(D d, const uint32_t idx3,
                                                  const uint32_t idx2,
                                                  const uint32_t idx1,
                                                  const uint32_t idx0) {
  return TblLookupPer4LaneBlkU8IdxInBlk(d, idx3, idx2, idx1, idx0);
}

#if HWY_TARGET == HWY_RVV
template <class D, HWY_IF_NOT_T_SIZE_D(D, 1)>
HWY_INLINE VFromD<D> TblLookupPer4LaneBlkIdxInBlk(D d, const uint32_t idx3,
                                                  const uint32_t idx2,
                                                  const uint32_t idx1,
                                                  const uint32_t idx0) {
  const Rebind<uint8_t, decltype(d)> du8;
  return PromoteTo(d,
                   TblLookupPer4LaneBlkU8IdxInBlk(du8, idx3, idx2, idx1, idx0));
}
#else
template <class D, HWY_IF_T_SIZE_D(D, 2)>
HWY_INLINE VFromD<D> TblLookupPer4LaneBlkIdxInBlk(D d, const uint32_t idx3,
                                                  const uint32_t idx2,
                                                  const uint32_t idx1,
                                                  const uint32_t idx0) {
  const uint16_t u16_idx0 = static_cast<uint16_t>(idx0);
  const uint16_t u16_idx1 = static_cast<uint16_t>(idx1);
  const uint16_t u16_idx2 = static_cast<uint16_t>(idx2);
  const uint16_t u16_idx3 = static_cast<uint16_t>(idx3);
  alignas(16)
      const uint16_t indices[8] = {u16_idx0, u16_idx1, u16_idx2, u16_idx3,
                                   u16_idx0, u16_idx1, u16_idx2, u16_idx3};

#if HWY_TARGET == HWY_NEON || HWY_TARGET == HWY_NEON_WITHOUT_AES
  constexpr size_t kMinLanesToLoad = 4;
#else
  constexpr size_t kMinLanesToLoad = 8;
#endif
  constexpr size_t kNumToLoad = HWY_MAX(HWY_MAX_LANES_D(D), kMinLanesToLoad);
  const CappedTag<uint16_t, kNumToLoad> d_load;

  return ResizeBitCast(d, LoadDup128(d_load, indices));
}

template <class D, HWY_IF_T_SIZE_D(D, 4)>
HWY_INLINE VFromD<D> TblLookupPer4LaneBlkIdxInBlk(D d, const uint32_t idx3,
                                                  const uint32_t idx2,
                                                  const uint32_t idx1,
                                                  const uint32_t idx0) {
  return Per4LaneBlkShufDupSet4xU32(d, idx3, idx2, idx1, idx0);
}

template <class D, HWY_IF_T_SIZE_D(D, 8)>
HWY_INLINE VFromD<D> TblLookupPer4LaneBlkIdxInBlk(D d, const uint32_t idx3,
                                                  const uint32_t idx2,
                                                  const uint32_t idx1,
                                                  const uint32_t idx0) {
  const RebindToUnsigned<decltype(d)> du;
  const Rebind<uint32_t, decltype(d)> du32;
  return BitCast(d, PromoteTo(du, Per4LaneBlkShufDupSet4xU32(du32, idx3, idx2,
                                                             idx1, idx0)));
}
#endif

template <class D, HWY_PER_4_BLK_TBL_LOOKUP_LANES_ENABLE(D)>
HWY_INLINE IndicesFromD<D> TblLookupPer4LaneBlkShufIdx(D d, const uint32_t idx3,
                                                       const uint32_t idx2,
                                                       const uint32_t idx1,
                                                       const uint32_t idx0) {
  const RebindToUnsigned<decltype(d)> du;
  using TU = TFromD<decltype(du)>;
  auto idx_in_blk = TblLookupPer4LaneBlkIdxInBlk(du, idx3, idx2, idx1, idx0);

  constexpr size_t kN = HWY_MAX_LANES_D(D);
  if (kN < 4) {
    idx_in_blk = And(idx_in_blk, Set(du, static_cast<TU>(kN - 1)));
  }

#if HWY_TARGET == HWY_RVV
  const auto blk_offsets = AndS(Iota0(du), static_cast<TU>(~TU{3}));
#else
  const auto blk_offsets =
      And(Iota(du, TU{0}), Set(du, static_cast<TU>(~TU{3})));
#endif
  return IndicesFromVec(d, Add(idx_in_blk, blk_offsets));
}

template <class V, HWY_PER_4_BLK_TBL_LOOKUP_LANES_ENABLE(DFromV<V>)>
HWY_INLINE V Per4LaneBlkShufDoTblLookup(V v, IndicesFromD<DFromV<V>> idx) {
  return TableLookupLanes(v, idx);
}

#undef HWY_PER_4_BLK_TBL_LOOKUP_LANES_ENABLE

template <class V>
HWY_INLINE V TblLookupPer4LaneBlkShuf(V v, size_t idx3210) {
  const DFromV<decltype(v)> d;
  const uint32_t idx3 = static_cast<uint32_t>((idx3210 >> 6) & 3);
  const uint32_t idx2 = static_cast<uint32_t>((idx3210 >> 4) & 3);
  const uint32_t idx1 = static_cast<uint32_t>((idx3210 >> 2) & 3);
  const uint32_t idx0 = static_cast<uint32_t>(idx3210 & 3);
  const auto idx = TblLookupPer4LaneBlkShufIdx(d, idx3, idx2, idx1, idx0);
  return Per4LaneBlkShufDoTblLookup(v, idx);
}

// The detail::Per4LaneBlockShuffle overloads that have the extra lane_size_tag
// and vect_size_tag parameters are only called for vectors that have at
// least 4 lanes (or scalable vectors that might possibly have 4 or more lanes)
template <size_t kIdx3210, size_t kLaneSize, size_t kVectSize, class V>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<kIdx3210> /*idx_3210_tag*/,
                                  hwy::SizeTag<kLaneSize> /*lane_size_tag*/,
                                  hwy::SizeTag<kVectSize> /*vect_size_tag*/,
                                  V v) {
  return TblLookupPer4LaneBlkShuf(v, kIdx3210);
}

#if HWY_HAVE_FLOAT64
template <class V>
HWY_INLINE VFromD<RepartitionToWide<DFromV<V>>> Per4LaneBlockShufCastToWide(
    hwy::FloatTag /* type_tag */, hwy::SizeTag<4> /* lane_size_tag */, V v) {
  const DFromV<decltype(v)> d;
  const RepartitionToWide<decltype(d)> dw;
  return BitCast(dw, v);
}
#endif

template <size_t kLaneSize, class V>
HWY_INLINE VFromD<RepartitionToWide<RebindToUnsigned<DFromV<V>>>>
Per4LaneBlockShufCastToWide(hwy::FloatTag /* type_tag */,
                            hwy::SizeTag<kLaneSize> /* lane_size_tag */, V v) {
  const DFromV<decltype(v)> d;
  const RebindToUnsigned<decltype(d)> du;
  const RepartitionToWide<decltype(du)> dw;
  return BitCast(dw, v);
}

template <size_t kLaneSize, class V>
HWY_INLINE VFromD<RepartitionToWide<DFromV<V>>> Per4LaneBlockShufCastToWide(
    hwy::NonFloatTag /* type_tag */,
    hwy::SizeTag<kLaneSize> /* lane_size_tag */, V v) {
  const DFromV<decltype(v)> d;
  const RepartitionToWide<decltype(d)> dw;
  return BitCast(dw, v);
}

template <class V>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0x1B> /*idx_3210_tag*/, V v) {
  const DFromV<decltype(v)> d;
  return Reverse4(d, v);
}

template <class V,
          HWY_IF_T_SIZE_ONE_OF_V(V, (1 << 1) | (1 << 2) |
                                        (HWY_HAVE_INTEGER64 ? (1 << 4) : 0))>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0x44> /*idx_3210_tag*/, V v) {
  const DFromV<decltype(v)> d;
  const auto vw = Per4LaneBlockShufCastToWide(
      hwy::IsFloatTag<TFromV<V>>(), hwy::SizeTag<sizeof(TFromV<V>)>(), v);
  return BitCast(d, DupEven(vw));
}

template <class V,
          HWY_IF_T_SIZE_ONE_OF_V(V, (1 << 1) | (1 << 2) |
                                        (HWY_HAVE_INTEGER64 ? (1 << 4) : 0))>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0x4E> /*idx_3210_tag*/, V v) {
  const DFromV<decltype(v)> d;
  const auto vw = Per4LaneBlockShufCastToWide(
      hwy::IsFloatTag<TFromV<V>>(), hwy::SizeTag<sizeof(TFromV<V>)>(), v);
  const DFromV<decltype(vw)> dw;
  return BitCast(d, Reverse2(dw, vw));
}

#if HWY_MAX_BYTES >= 32
template <class V, HWY_IF_T_SIZE_V(V, 8)>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0x4E> /*idx_3210_tag*/, V v) {
  return SwapAdjacentBlocks(v);
}
#endif

template <class V, HWY_IF_LANES_D(DFromV<V>, 4),
          HWY_IF_T_SIZE_ONE_OF_V(V, (1 << 1) | (1 << 2))>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0x50> /*idx_3210_tag*/, V v) {
  const DFromV<decltype(v)> d;
  return InterleaveLower(d, v, v);
}

template <class V, HWY_IF_T_SIZE_V(V, 4)>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0x50> /*idx_3210_tag*/, V v) {
  const DFromV<decltype(v)> d;
  return InterleaveLower(d, v, v);
}

template <class V, HWY_IF_LANES_D(DFromV<V>, 4)>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0x88> /*idx_3210_tag*/, V v) {
  const DFromV<decltype(v)> d;
  return ConcatEven(d, v, v);
}

template <class V>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0xA0> /*idx_3210_tag*/, V v) {
  return DupEven(v);
}

template <class V>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0xB1> /*idx_3210_tag*/, V v) {
  const DFromV<decltype(v)> d;
  return Reverse2(d, v);
}

template <class V, HWY_IF_LANES_D(DFromV<V>, 4)>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0xDD> /*idx_3210_tag*/, V v) {
  const DFromV<decltype(v)> d;
  return ConcatOdd(d, v, v);
}

template <class V>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0xE4> /*idx_3210_tag*/, V v) {
  return v;
}

template <class V,
          HWY_IF_T_SIZE_ONE_OF_V(V, (1 << 1) | (1 << 2) |
                                        (HWY_HAVE_INTEGER64 ? (1 << 4) : 0))>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0xEE> /*idx_3210_tag*/, V v) {
  const DFromV<decltype(v)> d;
  const auto vw = Per4LaneBlockShufCastToWide(
      hwy::IsFloatTag<TFromV<V>>(), hwy::SizeTag<sizeof(TFromV<V>)>(), v);
  return BitCast(d, DupOdd(vw));
}

template <class V>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0xF5> /*idx_3210_tag*/, V v) {
  return DupOdd(v);
}

template <class V, HWY_IF_T_SIZE_V(V, 4)>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<0xFA> /*idx_3210_tag*/, V v) {
  const DFromV<decltype(v)> d;
  return InterleaveUpper(d, v, v);
}

template <size_t kIdx3210, class V>
HWY_INLINE V Per4LaneBlockShuffle(hwy::SizeTag<kIdx3210> idx_3210_tag, V v) {
  const DFromV<decltype(v)> d;
  return Per4LaneBlockShuffle(idx_3210_tag, hwy::SizeTag<sizeof(TFromV<V>)>(),
                              hwy::SizeTag<d.MaxBytes()>(), v);
}

}  // namespace detail
#endif  // HWY_TARGET != HWY_SCALAR

template <size_t kIdx3, size_t kIdx2, size_t kIdx1, size_t kIdx0, class V,
          HWY_IF_LANES_D(DFromV<V>, 1)>
HWY_API V Per4LaneBlockShuffle(V v) {
  static_assert(kIdx0 <= 3, "kIdx0 <= 3 must be true");
  static_assert(kIdx1 <= 3, "kIdx1 <= 3 must be true");
  static_assert(kIdx2 <= 3, "kIdx2 <= 3 must be true");
  static_assert(kIdx3 <= 3, "kIdx3 <= 3 must be true");

  return v;
}

#if HWY_TARGET != HWY_SCALAR
template <size_t kIdx3, size_t kIdx2, size_t kIdx1, size_t kIdx0, class V,
          HWY_IF_LANES_D(DFromV<V>, 2)>
HWY_API V Per4LaneBlockShuffle(V v) {
  static_assert(kIdx0 <= 3, "kIdx0 <= 3 must be true");
  static_assert(kIdx1 <= 3, "kIdx1 <= 3 must be true");
  static_assert(kIdx2 <= 3, "kIdx2 <= 3 must be true");
  static_assert(kIdx3 <= 3, "kIdx3 <= 3 must be true");

  constexpr bool isReverse2 = (kIdx0 == 1 || kIdx1 == 0) && (kIdx0 != kIdx1);
  constexpr size_t kPer2BlkIdx0 = (kIdx0 <= 1) ? kIdx0 : (isReverse2 ? 1 : 0);
  constexpr size_t kPer2BlkIdx1 = (kIdx1 <= 1) ? kIdx1 : (isReverse2 ? 0 : 1);

  constexpr size_t kIdx10 = (kPer2BlkIdx1 << 1) | kPer2BlkIdx0;
  static_assert(kIdx10 <= 3, "kIdx10 <= 3 must be true");
  return detail::Per2LaneBlockShuffle(hwy::SizeTag<kIdx10>(), v);
}

template <size_t kIdx3, size_t kIdx2, size_t kIdx1, size_t kIdx0, class V,
          HWY_IF_LANES_GT_D(DFromV<V>, 2)>
HWY_API V Per4LaneBlockShuffle(V v) {
  static_assert(kIdx0 <= 3, "kIdx0 <= 3 must be true");
  static_assert(kIdx1 <= 3, "kIdx1 <= 3 must be true");
  static_assert(kIdx2 <= 3, "kIdx2 <= 3 must be true");
  static_assert(kIdx3 <= 3, "kIdx3 <= 3 must be true");

  constexpr size_t kIdx3210 =
      (kIdx3 << 6) | (kIdx2 << 4) | (kIdx1 << 2) | kIdx0;
  return detail::Per4LaneBlockShuffle(hwy::SizeTag<kIdx3210>(), v);
}
#endif

// ------------------------------ Blocks

template <class D>
HWY_API size_t Blocks(D d) {
  return (d.MaxBytes() <= 16) ? 1 : ((Lanes(d) * sizeof(TFromD<D>) + 15) / 16);
}

// ------------------------------ Block insert/extract/broadcast ops
#if (defined(HWY_NATIVE_BLK_INSERT_EXTRACT) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_BLK_INSERT_EXTRACT
#undef HWY_NATIVE_BLK_INSERT_EXTRACT
#else
#define HWY_NATIVE_BLK_INSERT_EXTRACT
#endif

template <int kBlockIdx, class V, HWY_IF_V_SIZE_LE_V(V, 16)>
HWY_API V InsertBlock(V /*v*/, V blk_to_insert) {
  static_assert(kBlockIdx == 0, "Invalid block index");
  return blk_to_insert;
}

template <int kBlockIdx, class V, HWY_IF_V_SIZE_LE_V(V, 16)>
HWY_API V ExtractBlock(V v) {
  static_assert(kBlockIdx == 0, "Invalid block index");
  return v;
}

template <int kBlockIdx, class V, HWY_IF_V_SIZE_LE_V(V, 16)>
HWY_API V BroadcastBlock(V v) {
  static_assert(kBlockIdx == 0, "Invalid block index");
  return v;
}

#endif  // HWY_NATIVE_BLK_INSERT_EXTRACT

// ------------------------------ BroadcastLane
#if (defined(HWY_NATIVE_BROADCASTLANE) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_BROADCASTLANE
#undef HWY_NATIVE_BROADCASTLANE
#else
#define HWY_NATIVE_BROADCASTLANE
#endif

template <int kLane, class V, HWY_IF_V_SIZE_LE_V(V, 16)>
HWY_API V BroadcastLane(V v) {
  return Broadcast<kLane>(v);
}

#endif  // HWY_NATIVE_BROADCASTLANE

// ------------------------------ Slide1Up and Slide1Down
#if (defined(HWY_NATIVE_SLIDE1_UP_DOWN) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_SLIDE1_UP_DOWN
#undef HWY_NATIVE_SLIDE1_UP_DOWN
#else
#define HWY_NATIVE_SLIDE1_UP_DOWN
#endif

template <class D, HWY_IF_LANES_D(D, 1)>
HWY_API VFromD<D> Slide1Up(D d, VFromD<D> /*v*/) {
  return Zero(d);
}
template <class D, HWY_IF_LANES_D(D, 1)>
HWY_API VFromD<D> Slide1Down(D d, VFromD<D> /*v*/) {
  return Zero(d);
}

#if HWY_TARGET != HWY_SCALAR
template <class D, HWY_IF_V_SIZE_LE_D(D, 16), HWY_IF_LANES_GT_D(D, 1)>
HWY_API VFromD<D> Slide1Up(D d, VFromD<D> v) {
  return ShiftLeftLanes<1>(d, v);
}
template <class D, HWY_IF_V_SIZE_LE_D(D, 16), HWY_IF_LANES_GT_D(D, 1)>
HWY_API VFromD<D> Slide1Down(D d, VFromD<D> v) {
  return ShiftRightLanes<1>(d, v);
}
#endif  // HWY_TARGET != HWY_SCALAR

#endif  // HWY_NATIVE_SLIDE1_UP_DOWN

// ------------------------------ SlideUpBlocks

template <int kBlocks, class D, HWY_IF_V_SIZE_LE_D(D, 16)>
HWY_API VFromD<D> SlideUpBlocks(D /*d*/, VFromD<D> v) {
  static_assert(kBlocks == 0, "kBlocks == 0 must be true");
  return v;
}

#if HWY_HAVE_SCALABLE || HWY_TARGET == HWY_SVE_256
template <int kBlocks, class D, HWY_IF_V_SIZE_GT_D(D, 16)>
HWY_API VFromD<D> SlideUpBlocks(D d, VFromD<D> v) {
  static_assert(0 <= kBlocks && static_cast<size_t>(kBlocks) < d.MaxBlocks(),
                "kBlocks must be between 0 and d.MaxBlocks() - 1");
  constexpr size_t kLanesPerBlock = 16 / sizeof(TFromD<D>);
  return SlideUpLanes(d, v, static_cast<size_t>(kBlocks) * kLanesPerBlock);
}
#endif

// ------------------------------ SlideDownBlocks

template <int kBlocks, class D, HWY_IF_V_SIZE_LE_D(D, 16)>
HWY_API VFromD<D> SlideDownBlocks(D /*d*/, VFromD<D> v) {
  static_assert(kBlocks == 0, "kBlocks == 0 must be true");
  return v;
}

#if HWY_HAVE_SCALABLE || HWY_TARGET == HWY_SVE_256
template <int kBlocks, class D, HWY_IF_V_SIZE_GT_D(D, 16)>
HWY_API VFromD<D> SlideDownBlocks(D d, VFromD<D> v) {
  static_assert(0 <= kBlocks && static_cast<size_t>(kBlocks) < d.MaxBlocks(),
                "kBlocks must be between 0 and d.MaxBlocks() - 1");
  constexpr size_t kLanesPerBlock = 16 / sizeof(TFromD<D>);
  return SlideDownLanes(d, v, static_cast<size_t>(kBlocks) * kLanesPerBlock);
}
#endif

// ================================================== Operator wrapper

// SVE* and RVV currently cannot define operators and have already defined
// (only) the corresponding functions such as Add.
#if (defined(HWY_NATIVE_OPERATOR_REPLACEMENTS) == defined(HWY_TARGET_TOGGLE))
#ifdef HWY_NATIVE_OPERATOR_REPLACEMENTS
#undef HWY_NATIVE_OPERATOR_REPLACEMENTS
#else
#define HWY_NATIVE_OPERATOR_REPLACEMENTS
#endif

template <class V>
HWY_API V Add(V a, V b) {
  return a + b;
}
template <class V>
HWY_API V Sub(V a, V b) {
  return a - b;
}

template <class V>
HWY_API V Mul(V a, V b) {
  return a * b;
}
template <class V>
HWY_API V Div(V a, V b) {
  return a / b;
}

template <class V>
V Shl(V a, V b) {
  return a << b;
}
template <class V>
V Shr(V a, V b) {
  return a >> b;
}

template <class V>
HWY_API auto Eq(V a, V b) -> decltype(a == b) {
  return a == b;
}
template <class V>
HWY_API auto Ne(V a, V b) -> decltype(a == b) {
  return a != b;
}
template <class V>
HWY_API auto Lt(V a, V b) -> decltype(a == b) {
  return a < b;
}

template <class V>
HWY_API auto Gt(V a, V b) -> decltype(a == b) {
  return a > b;
}
template <class V>
HWY_API auto Ge(V a, V b) -> decltype(a == b) {
  return a >= b;
}

template <class V>
HWY_API auto Le(V a, V b) -> decltype(a == b) {
  return a <= b;
}

#endif  // HWY_NATIVE_OPERATOR_REPLACEMENTS

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace hwy
HWY_AFTER_NAMESPACE();
