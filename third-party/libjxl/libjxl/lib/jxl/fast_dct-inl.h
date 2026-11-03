// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#if defined(LIB_JXL_FAST_DCT_INL_H_) == defined(HWY_TARGET_TOGGLE)
#ifdef LIB_JXL_FAST_DCT_INL_H_
#undef LIB_JXL_FAST_DCT_INL_H_
#else
#define LIB_JXL_FAST_DCT_INL_H_
#endif

#include <cmath>
#include <hwy/aligned_allocator.h>
#include <hwy/highway.h>

#include "lib/jxl/base/status.h"

HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {
namespace {

#if HWY_TARGET == HWY_NEON
HWY_NOINLINE void FastTransposeBlock(const int16_t* JXL_RESTRICT data_in,
                                     size_t stride_in, size_t N, size_t M,
                                     int16_t* JXL_RESTRICT data_out,
                                     size_t stride_out) {
  JXL_DASSERT(N % 8 == 0);
  JXL_DASSERT(M % 8 == 0);
  for (size_t i = 0; i < N; i += 8) {
    for (size_t j = 0; j < M; j += 8) {
      // TODO(veluca): one could optimize the M==8, stride_in==8 case further
      // with vld4.
      // This code is about 40% faster for N == M == stride_in ==
      // stride_out == 8
      // Using loads + stores to reshuffle things to be able to
      // use vld4 doesn't help.
      /*
      auto a0 = vld4q_s16(data_in); auto a1 = vld4q_s16(data_in + 32);
      int16x8x4_t out0;
      int16x8x4_t out1;
      out0.val[0] = vuzp1q_s16(a0.val[0], a1.val[0]);
      out0.val[1] = vuzp1q_s16(a0.val[1], a1.val[1]);
      out0.val[2] = vuzp1q_s16(a0.val[2], a1.val[2]);
      out0.val[3] = vuzp1q_s16(a0.val[3], a1.val[3]);
      out1.val[0] = vuzp2q_s16(a0.val[0], a1.val[0]);
      out1.val[1] = vuzp2q_s16(a0.val[1], a1.val[1]);
      out1.val[2] = vuzp2q_s16(a0.val[2], a1.val[2]);
      out1.val[3] = vuzp2q_s16(a0.val[3], a1.val[3]);
      vst1q_s16_x4(data_out, out0);
      vst1q_s16_x4(data_out + 32, out1);
      */
      auto a0 = vld1q_s16(data_in + i * stride_in + j);
      auto a1 = vld1q_s16(data_in + (i + 1) * stride_in + j);
      auto a2 = vld1q_s16(data_in + (i + 2) * stride_in + j);
      auto a3 = vld1q_s16(data_in + (i + 3) * stride_in + j);

      auto a01 = vtrnq_s16(a0, a1);
      auto a23 = vtrnq_s16(a2, a3);

      auto four0 = vtrnq_s32(vreinterpretq_s32_s16(a01.val[0]),
                             vreinterpretq_s32_s16(a23.val[0]));
      auto four1 = vtrnq_s32(vreinterpretq_s32_s16(a01.val[1]),
                             vreinterpretq_s32_s16(a23.val[1]));

      auto a4 = vld1q_s16(data_in + (i + 4) * stride_in + j);
      auto a5 = vld1q_s16(data_in + (i + 5) * stride_in + j);
      auto a6 = vld1q_s16(data_in + (i + 6) * stride_in + j);
      auto a7 = vld1q_s16(data_in + (i + 7) * stride_in + j);

      auto a45 = vtrnq_s16(a4, a5);
      auto a67 = vtrnq_s16(a6, a7);

      auto four2 = vtrnq_s32(vreinterpretq_s32_s16(a45.val[0]),
                             vreinterpretq_s32_s16(a67.val[0]));
      auto four3 = vtrnq_s32(vreinterpretq_s32_s16(a45.val[1]),
                             vreinterpretq_s32_s16(a67.val[1]));

      auto out0 =
          vcombine_s32(vget_low_s32(four0.val[0]), vget_low_s32(four2.val[0]));
      auto out1 =
          vcombine_s32(vget_low_s32(four1.val[0]), vget_low_s32(four3.val[0]));
      auto out2 =
          vcombine_s32(vget_low_s32(four0.val[1]), vget_low_s32(four2.val[1]));
      auto out3 =
          vcombine_s32(vget_low_s32(four1.val[1]), vget_low_s32(four3.val[1]));
      auto out4 = vcombine_s32(vget_high_s32(four0.val[0]),
                               vget_high_s32(four2.val[0]));
      auto out5 = vcombine_s32(vget_high_s32(four1.val[0]),
                               vget_high_s32(four3.val[0]));
      auto out6 = vcombine_s32(vget_high_s32(four0.val[1]),
                               vget_high_s32(four2.val[1]));
      auto out7 = vcombine_s32(vget_high_s32(four1.val[1]),
                               vget_high_s32(four3.val[1]));
      vst1q_s16(data_out + j * stride_out + i, vreinterpretq_s16_s32(out0));
      vst1q_s16(data_out + (j + 1) * stride_out + i,
                vreinterpretq_s16_s32(out1));
      vst1q_s16(data_out + (j + 2) * stride_out + i,
                vreinterpretq_s16_s32(out2));
      vst1q_s16(data_out + (j + 3) * stride_out + i,
                vreinterpretq_s16_s32(out3));
      vst1q_s16(data_out + (j + 4) * stride_out + i,
                vreinterpretq_s16_s32(out4));
      vst1q_s16(data_out + (j + 5) * stride_out + i,
                vreinterpretq_s16_s32(out5));
      vst1q_s16(data_out + (j + 6) * stride_out + i,
                vreinterpretq_s16_s32(out6));
      vst1q_s16(data_out + (j + 7) * stride_out + i,
                vreinterpretq_s16_s32(out7));
    }
  }
}

template <size_t N>
struct FastDCTTag {};

#include "lib/jxl/fast_dct128-inl.h"
#include "lib/jxl/fast_dct16-inl.h"
#include "lib/jxl/fast_dct256-inl.h"
#include "lib/jxl/fast_dct32-inl.h"
#include "lib/jxl/fast_dct64-inl.h"
#include "lib/jxl/fast_dct8-inl.h"

template <size_t ROWS, size_t COLS>
struct ComputeFastScaledIDCT {
  // scratch_space must be aligned, and should have space for ROWS*COLS
  // int16_ts.
  HWY_MAYBE_UNUSED void operator()(int16_t* JXL_RESTRICT from, int16_t* to,
                                   size_t to_stride,
                                   int16_t* JXL_RESTRICT scratch_space) {
    // Reverse the steps done in ComputeScaledDCT.
    if (ROWS < COLS) {
      FastTransposeBlock(from, COLS, ROWS, COLS, scratch_space, ROWS);
      FastIDCT(FastDCTTag<COLS>(), scratch_space, ROWS, from, ROWS, ROWS);
      FastTransposeBlock(from, ROWS, COLS, ROWS, scratch_space, COLS);
      FastIDCT(FastDCTTag<ROWS>(), scratch_space, COLS, to, to_stride, COLS);
    } else {
      FastIDCT(FastDCTTag<COLS>(), from, ROWS, scratch_space, ROWS, ROWS);
      FastTransposeBlock(scratch_space, ROWS, COLS, ROWS, from, COLS);
      FastIDCT(FastDCTTag<ROWS>(), from, COLS, to, to_stride, COLS);
    }
  }
};
#endif

template <size_t N, size_t M>
HWY_NOINLINE void TestFastIDCT() {
#if HWY_TARGET == HWY_NEON
  auto pixels_mem = hwy::AllocateAligned<float>(N * M);
  float* pixels = pixels_mem.get();
  auto dct_mem = hwy::AllocateAligned<float>(N * M);
  float* dct = dct_mem.get();
  auto dct_i_mem = hwy::AllocateAligned<int16_t>(N * M);
  int16_t* dct_i = dct_i_mem.get();
  auto dct_in_mem = hwy::AllocateAligned<int16_t>(N * M);
  int16_t* dct_in = dct_in_mem.get();
  auto idct_mem = hwy::AllocateAligned<int16_t>(N * M);
  int16_t* idct = idct_mem.get();

  auto scratch_space_mem = hwy::AllocateAligned<float>(N * M * 2);
  float* scratch_space = scratch_space_mem.get();
  auto scratch_space_i_mem = hwy::AllocateAligned<int16_t>(N * M * 2);
  int16_t* scratch_space_i = scratch_space_i_mem.get();

  Rng rng(0);
  for (size_t i = 0; i < N * M; i++) {
    pixels[i] = rng.UniformF(-1, 1);
  }
  ComputeScaledDCT<M, N>()(DCTFrom(pixels, N), dct, scratch_space);
  size_t integer_bits = std::max(FastIDCTIntegerBits(FastDCTTag<N>()),
                                 FastIDCTIntegerBits(FastDCTTag<M>()));
  // Enough range for [-2, 2] output values.
  JXL_ASSERT(integer_bits <= 14);
  float scale = (1 << (14 - integer_bits));
  for (size_t i = 0; i < N * M; i++) {
    dct_i[i] = std::round(dct[i] * scale);
  }

  for (size_t j = 0; j < 40000000 / (M * N); j++) {
    memcpy(dct_in, dct_i, sizeof(*dct_i) * N * M);
    ComputeFastScaledIDCT<M, N>()(dct_in, idct, N, scratch_space_i);
  }
  float max_error = 0;
  for (size_t i = 0; i < M * N; i++) {
    float err = std::abs(idct[i] * (1.0f / scale) - pixels[i]);
    if (std::abs(err) > max_error) {
      max_error = std::abs(err);
    }
  }
  printf("max error: %f mantissa bits: %d\n", max_error,
         14 - (int)integer_bits);
#endif
}

template <size_t N, size_t M>
HWY_NOINLINE void TestFloatIDCT() {
  auto pixels_mem = hwy::AllocateAligned<float>(N * M);
  float* pixels = pixels_mem.get();
  auto dct_mem = hwy::AllocateAligned<float>(N * M);
  float* dct = dct_mem.get();
  auto idct_mem = hwy::AllocateAligned<float>(N * M);
  float* idct = idct_mem.get();

  auto dct_in_mem = hwy::AllocateAligned<float>(N * M);
  float* dct_in = dct_mem.get();

  auto scratch_space_mem = hwy::AllocateAligned<float>(N * M * 2);
  float* scratch_space = scratch_space_mem.get();

  Rng rng(0);
  for (size_t i = 0; i < N * M; i++) {
    pixels[i] = rng.UniformF(-1, 1);
  }
  ComputeScaledDCT<M, N>()(DCTFrom(pixels, N), dct, scratch_space);

  for (size_t j = 0; j < 40000000 / (M * N); j++) {
    memcpy(dct_in, dct, sizeof(*dct) * N * M);
    ComputeScaledIDCT<M, N>()(dct_in, DCTTo(idct, N), scratch_space);
  }
  float max_error = 0;
  for (size_t i = 0; i < M * N; i++) {
    float err = std::abs(idct[i] - pixels[i]);
    if (std::abs(err) > max_error) {
      max_error = std::abs(err);
    }
  }
  printf("max error: %e\n", max_error);
}

}  // namespace
// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#endif  // LIB_JXL_FAST_DCT_INL_H_
