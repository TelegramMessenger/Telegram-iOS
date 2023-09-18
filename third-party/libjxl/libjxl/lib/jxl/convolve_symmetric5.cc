// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/convolve.h"

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/convolve_symmetric5.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jxl/common.h"  // RoundUpTo
#include "lib/jxl/convolve-inl.h"

HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::Add;
using hwy::HWY_NAMESPACE::Mul;
using hwy::HWY_NAMESPACE::Vec;

// Weighted sum of 1x5 pixels around ix, iy with [wx2 wx1 wx0 wx1 wx2].
template <class WrapY>
static float WeightedSumBorder(const ImageF& in, const WrapY wrap_y,
                               const int64_t ix, const int64_t iy,
                               const size_t xsize, const size_t ysize,
                               const float wx0, const float wx1,
                               const float wx2) {
  const WrapMirror wrap_x;
  const float* JXL_RESTRICT row = in.ConstRow(wrap_y(iy, ysize));
  const float in_m2 = row[wrap_x(ix - 2, xsize)];
  const float in_p2 = row[wrap_x(ix + 2, xsize)];
  const float in_m1 = row[wrap_x(ix - 1, xsize)];
  const float in_p1 = row[wrap_x(ix + 1, xsize)];
  const float in_00 = row[ix];
  const float sum_2 = wx2 * (in_m2 + in_p2);
  const float sum_1 = wx1 * (in_m1 + in_p1);
  const float sum_0 = wx0 * in_00;
  return sum_2 + sum_1 + sum_0;
}

template <class WrapY, class V>
static V WeightedSum(const ImageF& in, const WrapY wrap_y, const size_t ix,
                     const int64_t iy, const size_t ysize, const V wx0,
                     const V wx1, const V wx2) {
  const HWY_FULL(float) d;
  const float* JXL_RESTRICT center = in.ConstRow(wrap_y(iy, ysize)) + ix;
  const auto in_m2 = LoadU(d, center - 2);
  const auto in_p2 = LoadU(d, center + 2);
  const auto in_m1 = LoadU(d, center - 1);
  const auto in_p1 = LoadU(d, center + 1);
  const auto in_00 = Load(d, center);
  const auto sum_2 = Mul(wx2, Add(in_m2, in_p2));
  const auto sum_1 = Mul(wx1, Add(in_m1, in_p1));
  const auto sum_0 = Mul(wx0, in_00);
  return Add(sum_2, Add(sum_1, sum_0));
}

// Produces result for one pixel
template <class WrapY>
float Symmetric5Border(const ImageF& in, const Rect& rect, const int64_t ix,
                       const int64_t iy, const WeightsSymmetric5& weights) {
  const float w0 = weights.c[0];
  const float w1 = weights.r[0];
  const float w2 = weights.R[0];
  const float w4 = weights.d[0];
  const float w5 = weights.L[0];
  const float w8 = weights.D[0];

  const size_t xsize = rect.xsize();
  const size_t ysize = rect.ysize();
  const WrapY wrap_y;
  // Unrolled loop over all 5 rows of the kernel.
  float sum0 = WeightedSumBorder(in, wrap_y, ix, iy, xsize, ysize, w0, w1, w2);

  sum0 += WeightedSumBorder(in, wrap_y, ix, iy - 2, xsize, ysize, w2, w5, w8);
  float sum1 =
      WeightedSumBorder(in, wrap_y, ix, iy + 2, xsize, ysize, w2, w5, w8);

  sum0 += WeightedSumBorder(in, wrap_y, ix, iy - 1, xsize, ysize, w1, w4, w5);
  sum1 += WeightedSumBorder(in, wrap_y, ix, iy + 1, xsize, ysize, w1, w4, w5);

  return sum0 + sum1;
}

// Produces result for one vector's worth of pixels
template <class WrapY>
static void Symmetric5Interior(const ImageF& in, const Rect& rect,
                               const int64_t ix, const int64_t iy,
                               const WeightsSymmetric5& weights,
                               float* JXL_RESTRICT row_out) {
  const HWY_FULL(float) d;

  const auto w0 = LoadDup128(d, weights.c);
  const auto w1 = LoadDup128(d, weights.r);
  const auto w2 = LoadDup128(d, weights.R);
  const auto w4 = LoadDup128(d, weights.d);
  const auto w5 = LoadDup128(d, weights.L);
  const auto w8 = LoadDup128(d, weights.D);

  const size_t ysize = rect.ysize();
  const WrapY wrap_y;
  // Unrolled loop over all 5 rows of the kernel.
  auto sum0 = WeightedSum(in, wrap_y, ix, iy, ysize, w0, w1, w2);

  sum0 = Add(sum0, WeightedSum(in, wrap_y, ix, iy - 2, ysize, w2, w5, w8));
  auto sum1 = WeightedSum(in, wrap_y, ix, iy + 2, ysize, w2, w5, w8);

  sum0 = Add(sum0, WeightedSum(in, wrap_y, ix, iy - 1, ysize, w1, w4, w5));
  sum1 = Add(sum1, WeightedSum(in, wrap_y, ix, iy + 1, ysize, w1, w4, w5));

  Store(Add(sum0, sum1), d, row_out + ix);
}

template <class WrapY>
static void Symmetric5Row(const ImageF& in, const Rect& rect, const int64_t iy,
                          const WeightsSymmetric5& weights,
                          float* JXL_RESTRICT row_out) {
  const int64_t kRadius = 2;
  const size_t xsize = rect.xsize();

  size_t ix = 0;
  const HWY_FULL(float) d;
  const size_t N = Lanes(d);
  const size_t aligned_x = RoundUpTo(kRadius, N);
  for (; ix < std::min(aligned_x, xsize); ++ix) {
    row_out[ix] = Symmetric5Border<WrapY>(in, rect, ix, iy, weights);
  }
  for (; ix + N + kRadius <= xsize; ix += N) {
    Symmetric5Interior<WrapY>(in, rect, ix, iy, weights, row_out);
  }
  for (; ix < xsize; ++ix) {
    row_out[ix] = Symmetric5Border<WrapY>(in, rect, ix, iy, weights);
  }
}

static JXL_NOINLINE void Symmetric5BorderRow(const ImageF& in, const Rect& rect,
                                             const int64_t iy,
                                             const WeightsSymmetric5& weights,
                                             float* JXL_RESTRICT row_out) {
  return Symmetric5Row<WrapMirror>(in, rect, iy, weights, row_out);
}

// Semi-vectorized (interior pixels Fonly); called directly like slow::, unlike
// the fully vectorized strategies below.
void Symmetric5(const ImageF& in, const Rect& rect,
                const WeightsSymmetric5& weights, ThreadPool* pool,
                ImageF* JXL_RESTRICT out) {
  const size_t ysize = rect.ysize();
  JXL_CHECK(RunOnPool(
      pool, 0, static_cast<uint32_t>(ysize), ThreadPool::NoInit,
      [&](const uint32_t task, size_t /*thread*/) {
        const int64_t iy = task;

        if (iy < 2 || iy >= static_cast<ssize_t>(ysize) - 2) {
          Symmetric5BorderRow(in, rect, iy, weights, out->Row(iy));
        } else {
          Symmetric5Row<WrapUnchanged>(in, rect, iy, weights, out->Row(iy));
        }
      },
      "Symmetric5x5Convolution"));
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {

HWY_EXPORT(Symmetric5);
void Symmetric5(const ImageF& in, const Rect& rect,
                const WeightsSymmetric5& weights, ThreadPool* pool,
                ImageF* JXL_RESTRICT out) {
  return HWY_DYNAMIC_DISPATCH(Symmetric5)(in, rect, weights, pool, out);
}

}  // namespace jxl
#endif  // HWY_ONCE
