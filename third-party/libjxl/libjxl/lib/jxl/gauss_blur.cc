// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/gauss_blur.h"

#include <string.h>

#include <algorithm>
#include <cmath>

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/gauss_blur.cc"
#include <hwy/cache_control.h>
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/common.h"
#include "lib/jxl/image_ops.h"
#include "lib/jxl/matrix_ops.h"
HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::Add;
using hwy::HWY_NAMESPACE::Broadcast;
using hwy::HWY_NAMESPACE::GetLane;
using hwy::HWY_NAMESPACE::Mul;
using hwy::HWY_NAMESPACE::MulAdd;
using hwy::HWY_NAMESPACE::NegMulSub;
#if HWY_TARGET != HWY_SCALAR
using hwy::HWY_NAMESPACE::ShiftLeftLanes;
#endif
using hwy::HWY_NAMESPACE::Vec;

void FastGaussian1D(const hwy::AlignedUniquePtr<RecursiveGaussian>& rg,
                    const float* JXL_RESTRICT in, intptr_t width,
                    float* JXL_RESTRICT out) {
  // Although the current output depends on the previous output, we can unroll
  // up to 4x by precomputing up to fourth powers of the constants. Beyond that,
  // numerical precision might become a problem. Macro because this is tested
  // in #if alongside HWY_TARGET.
#define JXL_GAUSS_MAX_LANES 4
  using D = HWY_CAPPED(float, JXL_GAUSS_MAX_LANES);
  using V = Vec<D>;
  const D d;
  const V mul_in_1 = Load(d, rg->mul_in + 0 * 4);
  const V mul_in_3 = Load(d, rg->mul_in + 1 * 4);
  const V mul_in_5 = Load(d, rg->mul_in + 2 * 4);
  const V mul_prev_1 = Load(d, rg->mul_prev + 0 * 4);
  const V mul_prev_3 = Load(d, rg->mul_prev + 1 * 4);
  const V mul_prev_5 = Load(d, rg->mul_prev + 2 * 4);
  const V mul_prev2_1 = Load(d, rg->mul_prev2 + 0 * 4);
  const V mul_prev2_3 = Load(d, rg->mul_prev2 + 1 * 4);
  const V mul_prev2_5 = Load(d, rg->mul_prev2 + 2 * 4);
  V prev_1 = Zero(d);
  V prev_3 = Zero(d);
  V prev_5 = Zero(d);
  V prev2_1 = Zero(d);
  V prev2_3 = Zero(d);
  V prev2_5 = Zero(d);

  const intptr_t N = rg->radius;

  intptr_t n = -N + 1;
  // Left side with bounds checks and only write output after n >= 0.
  const intptr_t first_aligned = RoundUpTo(N + 1, Lanes(d));
  for (; n < std::min(first_aligned, width); ++n) {
    const intptr_t left = n - N - 1;
    const intptr_t right = n + N - 1;
    const float left_val = left >= 0 ? in[left] : 0.0f;
    const float right_val = right < width ? in[right] : 0.0f;
    const V sum = Set(d, left_val + right_val);

    // (Only processing a single lane here, no need to broadcast)
    V out_1 = Mul(sum, mul_in_1);
    V out_3 = Mul(sum, mul_in_3);
    V out_5 = Mul(sum, mul_in_5);

    out_1 = MulAdd(mul_prev2_1, prev2_1, out_1);
    out_3 = MulAdd(mul_prev2_3, prev2_3, out_3);
    out_5 = MulAdd(mul_prev2_5, prev2_5, out_5);
    prev2_1 = prev_1;
    prev2_3 = prev_3;
    prev2_5 = prev_5;

    out_1 = MulAdd(mul_prev_1, prev_1, out_1);
    out_3 = MulAdd(mul_prev_3, prev_3, out_3);
    out_5 = MulAdd(mul_prev_5, prev_5, out_5);
    prev_1 = out_1;
    prev_3 = out_3;
    prev_5 = out_5;

    if (n >= 0) {
      out[n] = GetLane(Add(out_1, Add(out_3, out_5)));
    }
  }

  // The above loop is effectively scalar but it is convenient to use the same
  // prev/prev2 variables, so broadcast to each lane before the unrolled loop.
#if HWY_TARGET != HWY_SCALAR && JXL_GAUSS_MAX_LANES > 1
  prev2_1 = Broadcast<0>(prev2_1);
  prev2_3 = Broadcast<0>(prev2_3);
  prev2_5 = Broadcast<0>(prev2_5);
  prev_1 = Broadcast<0>(prev_1);
  prev_3 = Broadcast<0>(prev_3);
  prev_5 = Broadcast<0>(prev_5);
#endif

  // Unrolled, no bounds checking needed.
  for (; n < width - N + 1 - (JXL_GAUSS_MAX_LANES - 1); n += Lanes(d)) {
    const V sum = Add(LoadU(d, in + n - N - 1), LoadU(d, in + n + N - 1));

    // To get a vector of output(s), we multiply broadcasted vectors (of each
    // input plus the two previous outputs) and add them all together.
    // Incremental broadcasting and shifting is expected to be cheaper than
    // horizontal adds or transposing 4x4 values because they run on a different
    // port, concurrently with the FMA.
    const V in0 = Broadcast<0>(sum);
    V out_1 = Mul(in0, mul_in_1);
    V out_3 = Mul(in0, mul_in_3);
    V out_5 = Mul(in0, mul_in_5);

#if HWY_TARGET != HWY_SCALAR && JXL_GAUSS_MAX_LANES >= 2
    const V in1 = Broadcast<1>(sum);
    out_1 = MulAdd(ShiftLeftLanes<1>(mul_in_1), in1, out_1);
    out_3 = MulAdd(ShiftLeftLanes<1>(mul_in_3), in1, out_3);
    out_5 = MulAdd(ShiftLeftLanes<1>(mul_in_5), in1, out_5);

#if JXL_GAUSS_MAX_LANES >= 4
    const V in2 = Broadcast<2>(sum);
    out_1 = MulAdd(ShiftLeftLanes<2>(mul_in_1), in2, out_1);
    out_3 = MulAdd(ShiftLeftLanes<2>(mul_in_3), in2, out_3);
    out_5 = MulAdd(ShiftLeftLanes<2>(mul_in_5), in2, out_5);

    const V in3 = Broadcast<3>(sum);
    out_1 = MulAdd(ShiftLeftLanes<3>(mul_in_1), in3, out_1);
    out_3 = MulAdd(ShiftLeftLanes<3>(mul_in_3), in3, out_3);
    out_5 = MulAdd(ShiftLeftLanes<3>(mul_in_5), in3, out_5);
#endif
#endif

    out_1 = MulAdd(mul_prev2_1, prev2_1, out_1);
    out_3 = MulAdd(mul_prev2_3, prev2_3, out_3);
    out_5 = MulAdd(mul_prev2_5, prev2_5, out_5);

    out_1 = MulAdd(mul_prev_1, prev_1, out_1);
    out_3 = MulAdd(mul_prev_3, prev_3, out_3);
    out_5 = MulAdd(mul_prev_5, prev_5, out_5);
#if HWY_TARGET == HWY_SCALAR || JXL_GAUSS_MAX_LANES == 1
    prev2_1 = prev_1;
    prev2_3 = prev_3;
    prev2_5 = prev_5;
    prev_1 = out_1;
    prev_3 = out_3;
    prev_5 = out_5;
#else
    prev2_1 = Broadcast<JXL_GAUSS_MAX_LANES - 2>(out_1);
    prev2_3 = Broadcast<JXL_GAUSS_MAX_LANES - 2>(out_3);
    prev2_5 = Broadcast<JXL_GAUSS_MAX_LANES - 2>(out_5);
    prev_1 = Broadcast<JXL_GAUSS_MAX_LANES - 1>(out_1);
    prev_3 = Broadcast<JXL_GAUSS_MAX_LANES - 1>(out_3);
    prev_5 = Broadcast<JXL_GAUSS_MAX_LANES - 1>(out_5);
#endif

    Store(Add(out_1, Add(out_3, out_5)), d, out + n);
  }

  // Remainder handling with bounds checks
  for (; n < width; ++n) {
    const intptr_t left = n - N - 1;
    const intptr_t right = n + N - 1;
    const float left_val = left >= 0 ? in[left] : 0.0f;
    const float right_val = right < width ? in[right] : 0.0f;
    const V sum = Set(d, left_val + right_val);

    // (Only processing a single lane here, no need to broadcast)
    V out_1 = Mul(sum, mul_in_1);
    V out_3 = Mul(sum, mul_in_3);
    V out_5 = Mul(sum, mul_in_5);

    out_1 = MulAdd(mul_prev2_1, prev2_1, out_1);
    out_3 = MulAdd(mul_prev2_3, prev2_3, out_3);
    out_5 = MulAdd(mul_prev2_5, prev2_5, out_5);
    prev2_1 = prev_1;
    prev2_3 = prev_3;
    prev2_5 = prev_5;

    out_1 = MulAdd(mul_prev_1, prev_1, out_1);
    out_3 = MulAdd(mul_prev_3, prev_3, out_3);
    out_5 = MulAdd(mul_prev_5, prev_5, out_5);
    prev_1 = out_1;
    prev_3 = out_3;
    prev_5 = out_5;

    out[n] = GetLane(Add(out_1, Add(out_3, out_5)));
  }
}

// Ring buffer is for n, n-1, n-2; round up to 4 for faster modulo.
constexpr size_t kMod = 4;

// Avoids an unnecessary store during warmup.
struct OutputNone {
  template <class V>
  void operator()(const V& /*unused*/, float* JXL_RESTRICT /*pos*/,
                  ptrdiff_t /*offset*/) const {}
};

// Common case: write output vectors in all VerticalBlock except warmup.
struct OutputStore {
  template <class V>
  void operator()(const V& out, float* JXL_RESTRICT pos,
                  ptrdiff_t offset) const {
    // Stream helps for large images but is slower for images that fit in cache.
    Store(out, HWY_FULL(float)(), pos + offset);
  }
};

// At top/bottom borders, we don't have two inputs to load, so avoid addition.
// pos may even point to all zeros if the row is outside the input image.
class SingleInput {
 public:
  explicit SingleInput(const float* pos) : pos_(pos) {}
  Vec<HWY_FULL(float)> operator()(const size_t offset) const {
    return Load(HWY_FULL(float)(), pos_ + offset);
  }
  const float* pos_;
};

// In the middle of the image, we need to load from a row above and below, and
// return the sum.
class TwoInputs {
 public:
  TwoInputs(const float* pos1, const float* pos2) : pos1_(pos1), pos2_(pos2) {}
  Vec<HWY_FULL(float)> operator()(const size_t offset) const {
    const auto in1 = Load(HWY_FULL(float)(), pos1_ + offset);
    const auto in2 = Load(HWY_FULL(float)(), pos2_ + offset);
    return Add(in1, in2);
  }

 private:
  const float* pos1_;
  const float* pos2_;
};

// Block := kVectors consecutive full vectors (one cache line except on the
// right boundary, where we can only rely on having one vector). Unrolling to
// the cache line size improves cache utilization.
template <size_t kVectors, class V, class Input, class Output>
void VerticalBlock(const V& d1_1, const V& d1_3, const V& d1_5, const V& n2_1,
                   const V& n2_3, const V& n2_5, const Input& input,
                   size_t& ctr, float* ring_buffer, const Output output,
                   float* JXL_RESTRICT out_pos) {
  const HWY_FULL(float) d;
  constexpr size_t kVN = MaxLanes(d);
  // More cache-friendly to process an entirely cache line at a time
  constexpr size_t kLanes = kVectors * kVN;

  float* JXL_RESTRICT y_1 = ring_buffer + 0 * kLanes * kMod;
  float* JXL_RESTRICT y_3 = ring_buffer + 1 * kLanes * kMod;
  float* JXL_RESTRICT y_5 = ring_buffer + 2 * kLanes * kMod;

  const size_t n_0 = (++ctr) % kMod;
  const size_t n_1 = (ctr - 1) % kMod;
  const size_t n_2 = (ctr - 2) % kMod;

  for (size_t idx_vec = 0; idx_vec < kVectors; ++idx_vec) {
    const V sum = input(idx_vec * kVN);

    const V y_n1_1 = Load(d, y_1 + kLanes * n_1 + idx_vec * kVN);
    const V y_n1_3 = Load(d, y_3 + kLanes * n_1 + idx_vec * kVN);
    const V y_n1_5 = Load(d, y_5 + kLanes * n_1 + idx_vec * kVN);
    const V y_n2_1 = Load(d, y_1 + kLanes * n_2 + idx_vec * kVN);
    const V y_n2_3 = Load(d, y_3 + kLanes * n_2 + idx_vec * kVN);
    const V y_n2_5 = Load(d, y_5 + kLanes * n_2 + idx_vec * kVN);
    // (35)
    const V y1 = MulAdd(n2_1, sum, NegMulSub(d1_1, y_n1_1, y_n2_1));
    const V y3 = MulAdd(n2_3, sum, NegMulSub(d1_3, y_n1_3, y_n2_3));
    const V y5 = MulAdd(n2_5, sum, NegMulSub(d1_5, y_n1_5, y_n2_5));
    Store(y1, d, y_1 + kLanes * n_0 + idx_vec * kVN);
    Store(y3, d, y_3 + kLanes * n_0 + idx_vec * kVN);
    Store(y5, d, y_5 + kLanes * n_0 + idx_vec * kVN);
    output(Add(y1, Add(y3, y5)), out_pos, idx_vec * kVN);
  }
  // NOTE: flushing cache line out_pos hurts performance - less so with
  // clflushopt than clflush but still a significant slowdown.
}

// Reads/writes one block (kVectors full vectors) in each row.
template <size_t kVectors>
void VerticalStrip(const hwy::AlignedUniquePtr<RecursiveGaussian>& rg,
                   const ImageF& in, const size_t x, ImageF* JXL_RESTRICT out) {
  // We're iterating vertically, so use multiple full-length vectors (each lane
  // is one column of row n).
  using D = HWY_FULL(float);
  using V = Vec<D>;
  const D d;
  constexpr size_t kVN = MaxLanes(d);
  // More cache-friendly to process an entirely cache line at a time
  constexpr size_t kLanes = kVectors * kVN;
#if HWY_TARGET == HWY_SCALAR
  const V d1_1 = Set(d, rg->d1[0 * 4]);
  const V d1_3 = Set(d, rg->d1[1 * 4]);
  const V d1_5 = Set(d, rg->d1[2 * 4]);
  const V n2_1 = Set(d, rg->n2[0 * 4]);
  const V n2_3 = Set(d, rg->n2[1 * 4]);
  const V n2_5 = Set(d, rg->n2[2 * 4]);
#else
  const V d1_1 = LoadDup128(d, rg->d1 + 0 * 4);
  const V d1_3 = LoadDup128(d, rg->d1 + 1 * 4);
  const V d1_5 = LoadDup128(d, rg->d1 + 2 * 4);
  const V n2_1 = LoadDup128(d, rg->n2 + 0 * 4);
  const V n2_3 = LoadDup128(d, rg->n2 + 1 * 4);
  const V n2_5 = LoadDup128(d, rg->n2 + 2 * 4);
#endif

  const size_t N = rg->radius;
  const size_t ysize = in.ysize();

  size_t ctr = 0;
  HWY_ALIGN float ring_buffer[3 * kLanes * kMod] = {0};
  HWY_ALIGN static constexpr float zero[kLanes] = {0};

  // Warmup: top is out of bounds (zero padded), bottom is usually in-bounds.
  ssize_t n = -static_cast<ssize_t>(N) + 1;
  for (; n < 0; ++n) {
    // bottom is always non-negative since n is initialized in -N + 1.
    const size_t bottom = n + N - 1;
    VerticalBlock<kVectors>(
        d1_1, d1_3, d1_5, n2_1, n2_3, n2_5,
        SingleInput(bottom < ysize ? in.ConstRow(bottom) + x : zero), ctr,
        ring_buffer, OutputNone(), nullptr);
  }
  JXL_DASSERT(n >= 0);

  // Start producing output; top is still out of bounds.
  for (; static_cast<size_t>(n) < std::min(N + 1, ysize); ++n) {
    const size_t bottom = n + N - 1;
    VerticalBlock<kVectors>(
        d1_1, d1_3, d1_5, n2_1, n2_3, n2_5,
        SingleInput(bottom < ysize ? in.ConstRow(bottom) + x : zero), ctr,
        ring_buffer, OutputStore(), out->Row(n) + x);
  }

  // Interior outputs with prefetching and without bounds checks.
  constexpr size_t kPrefetchRows = 8;
  for (; n < static_cast<ssize_t>(ysize - N + 1 - kPrefetchRows); ++n) {
    const size_t top = n - N - 1;
    const size_t bottom = n + N - 1;
    VerticalBlock<kVectors>(
        d1_1, d1_3, d1_5, n2_1, n2_3, n2_5,
        TwoInputs(in.ConstRow(top) + x, in.ConstRow(bottom) + x), ctr,
        ring_buffer, OutputStore(), out->Row(n) + x);
    hwy::Prefetch(in.ConstRow(top + kPrefetchRows) + x);
    hwy::Prefetch(in.ConstRow(bottom + kPrefetchRows) + x);
  }

  // Bottom border without prefetching and with bounds checks.
  for (; static_cast<size_t>(n) < ysize; ++n) {
    const size_t top = n - N - 1;
    const size_t bottom = n + N - 1;
    VerticalBlock<kVectors>(
        d1_1, d1_3, d1_5, n2_1, n2_3, n2_5,
        TwoInputs(in.ConstRow(top) + x,
                  bottom < ysize ? in.ConstRow(bottom) + x : zero),
        ctr, ring_buffer, OutputStore(), out->Row(n) + x);
  }
}

// Apply 1D vertical scan to multiple columns (one per vector lane).
// Not yet parallelized.
void FastGaussianVertical(const hwy::AlignedUniquePtr<RecursiveGaussian>& rg,
                          const ImageF& in, ThreadPool* /*pool*/,
                          ImageF* JXL_RESTRICT out) {
  JXL_CHECK(SameSize(in, *out));

  constexpr size_t kCacheLineLanes = 64 / sizeof(float);
  constexpr size_t kVN = MaxLanes(HWY_FULL(float)());
  constexpr size_t kCacheLineVectors =
      (kVN < kCacheLineLanes) ? (kCacheLineLanes / kVN) : 4;
  constexpr size_t kFastPace = kCacheLineVectors * kVN;

  size_t x = 0;
  for (; x + kFastPace <= in.xsize(); x += kFastPace) {
    VerticalStrip<kCacheLineVectors>(rg, in, x, out);
  }
  for (; x < in.xsize(); x += kVN) {
    VerticalStrip<1>(rg, in, x, out);
  }
}

// TODO(veluca): consider replacing with FastGaussian.
ImageF ConvolveXSampleAndTranspose(const ImageF& in,
                                   const std::vector<float>& kernel,
                                   const size_t res) {
  JXL_ASSERT(kernel.size() % 2 == 1);
  JXL_ASSERT(in.xsize() % res == 0);
  const size_t offset = res / 2;
  const size_t out_xsize = in.xsize() / res;
  ImageF out(in.ysize(), out_xsize);
  const int r = kernel.size() / 2;
  HWY_FULL(float) df;
  std::vector<float> row_tmp(in.xsize() + 2 * r + Lanes(df));
  float* const JXL_RESTRICT rowp = &row_tmp[r];
  std::vector<float> padded_k = kernel;
  padded_k.resize(padded_k.size() + Lanes(df));
  const float* const kernelp = &padded_k[r];
  for (size_t y = 0; y < in.ysize(); ++y) {
    ExtrapolateBorders(in.Row(y), rowp, in.xsize(), r);
    size_t x = offset, ox = 0;
    for (; x < static_cast<uint32_t>(r) && x < in.xsize(); x += res, ++ox) {
      float sum = 0.0f;
      for (int i = -r; i <= r; ++i) {
        sum += rowp[std::max<int>(
                   0, std::min<int>(static_cast<int>(x) + i, in.xsize()))] *
               kernelp[i];
      }
      out.Row(ox)[y] = sum;
    }
    for (; x + r < in.xsize(); x += res, ++ox) {
      auto sum = Zero(df);
      for (int i = -r; i <= r; i += Lanes(df)) {
        sum = MulAdd(LoadU(df, rowp + x + i), LoadU(df, kernelp + i), sum);
      }
      out.Row(ox)[y] = GetLane(SumOfLanes(df, sum));
    }
    for (; x < in.xsize(); x += res, ++ox) {
      float sum = 0.0f;
      for (int i = -r; i <= r; ++i) {
        sum += rowp[std::max<int>(
                   0, std::min<int>(static_cast<int>(x) + i, in.xsize()))] *
               kernelp[i];
      }
      out.Row(ox)[y] = sum;
    }
  }
  return out;
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {

HWY_EXPORT(FastGaussian1D);
HWY_EXPORT(ConvolveXSampleAndTranspose);
void FastGaussian1D(const hwy::AlignedUniquePtr<RecursiveGaussian>& rg,
                    const float* JXL_RESTRICT in, intptr_t width,
                    float* JXL_RESTRICT out) {
  return HWY_DYNAMIC_DISPATCH(FastGaussian1D)(rg, in, width, out);
}

HWY_EXPORT(FastGaussianVertical);  // Local function.

void ExtrapolateBorders(const float* const JXL_RESTRICT row_in,
                        float* const JXL_RESTRICT row_out, const int xsize,
                        const int radius) {
  const int lastcol = xsize - 1;
  for (int x = 1; x <= radius; ++x) {
    row_out[-x] = row_in[std::min(x, xsize - 1)];
  }
  memcpy(row_out, row_in, xsize * sizeof(row_out[0]));
  for (int x = 1; x <= radius; ++x) {
    row_out[lastcol + x] = row_in[std::max(0, lastcol - x)];
  }
}

ImageF ConvolveXSampleAndTranspose(const ImageF& in,
                                   const std::vector<float>& kernel,
                                   const size_t res) {
  return HWY_DYNAMIC_DISPATCH(ConvolveXSampleAndTranspose)(in, kernel, res);
}

Image3F ConvolveXSampleAndTranspose(const Image3F& in,
                                    const std::vector<float>& kernel,
                                    const size_t res) {
  return Image3F(ConvolveXSampleAndTranspose(in.Plane(0), kernel, res),
                 ConvolveXSampleAndTranspose(in.Plane(1), kernel, res),
                 ConvolveXSampleAndTranspose(in.Plane(2), kernel, res));
}

ImageF ConvolveAndSample(const ImageF& in, const std::vector<float>& kernel,
                         const size_t res) {
  ImageF tmp = ConvolveXSampleAndTranspose(in, kernel, res);
  return ConvolveXSampleAndTranspose(tmp, kernel, res);
}

// Implements "Recursive Implementation of the Gaussian Filter Using Truncated
// Cosine Functions" by Charalampidis [2016].
hwy::AlignedUniquePtr<RecursiveGaussian> CreateRecursiveGaussian(double sigma) {
  auto rg = hwy::MakeUniqueAligned<RecursiveGaussian>();
  constexpr double kPi = 3.141592653589793238;

  const double radius = roundf(3.2795 * sigma + 0.2546);  // (57), "N"

  // Table I, first row
  const double pi_div_2r = kPi / (2.0 * radius);
  const double omega[3] = {pi_div_2r, 3.0 * pi_div_2r, 5.0 * pi_div_2r};

  // (37), k={1,3,5}
  const double p_1 = +1.0 / std::tan(0.5 * omega[0]);
  const double p_3 = -1.0 / std::tan(0.5 * omega[1]);
  const double p_5 = +1.0 / std::tan(0.5 * omega[2]);

  // (44), k={1,3,5}
  const double r_1 = +p_1 * p_1 / std::sin(omega[0]);
  const double r_3 = -p_3 * p_3 / std::sin(omega[1]);
  const double r_5 = +p_5 * p_5 / std::sin(omega[2]);

  // (50), k={1,3,5}
  const double neg_half_sigma2 = -0.5 * sigma * sigma;
  const double recip_radius = 1.0 / radius;
  double rho[3];
  for (size_t i = 0; i < 3; ++i) {
    rho[i] = std::exp(neg_half_sigma2 * omega[i] * omega[i]) * recip_radius;
  }

  // second part of (52), k1,k2 = 1,3; 3,5; 5,1
  const double D_13 = p_1 * r_3 - r_1 * p_3;
  const double D_35 = p_3 * r_5 - r_3 * p_5;
  const double D_51 = p_5 * r_1 - r_5 * p_1;

  // (52), k=5
  const double recip_d13 = 1.0 / D_13;
  const double zeta_15 = D_35 * recip_d13;
  const double zeta_35 = D_51 * recip_d13;

  double A[9] = {p_1,     p_3,     p_5,  //
                 r_1,     r_3,     r_5,  //  (56)
                 zeta_15, zeta_35, 1};
  JXL_CHECK(Inv3x3Matrix(A));
  const double gamma[3] = {1, radius * radius - sigma * sigma,  // (55)
                           zeta_15 * rho[0] + zeta_35 * rho[1] + rho[2]};
  double beta[3];
  Mul3x3Vector(A, gamma, beta);  // (53)

  // Sanity check: correctly solved for beta (IIR filter weights are normalized)
  const double sum = beta[0] * p_1 + beta[1] * p_3 + beta[2] * p_5;  // (39)
  JXL_ASSERT(std::abs(sum - 1) < 1E-12);
  (void)sum;

  rg->radius = static_cast<int>(radius);

  double n2[3];
  double d1[3];
  for (size_t i = 0; i < 3; ++i) {
    n2[i] = -beta[i] * std::cos(omega[i] * (radius + 1.0));  // (33)
    d1[i] = -2.0 * std::cos(omega[i]);                       // (33)

    for (size_t lane = 0; lane < 4; ++lane) {
      rg->n2[4 * i + lane] = static_cast<float>(n2[i]);
      rg->d1[4 * i + lane] = static_cast<float>(d1[i]);
    }

    const double d_2 = d1[i] * d1[i];

    // Obtained by expanding (35) for four consecutive outputs via sympy:
    // n, d, p, pp = symbols('n d p pp')
    // i0, i1, i2, i3 = symbols('i0 i1 i2 i3')
    // o0, o1, o2, o3 = symbols('o0 o1 o2 o3')
    // o0 = n*i0 - d*p - pp
    // o1 = n*i1 - d*o0 - p
    // o2 = n*i2 - d*o1 - o0
    // o3 = n*i3 - d*o2 - o1
    // Then expand(o3) and gather terms for p(prev), pp(prev2) etc.
    rg->mul_prev[4 * i + 0] = -d1[i];
    rg->mul_prev[4 * i + 1] = d_2 - 1.0;
    rg->mul_prev[4 * i + 2] = -d_2 * d1[i] + 2.0 * d1[i];
    rg->mul_prev[4 * i + 3] = d_2 * d_2 - 3.0 * d_2 + 1.0;
    rg->mul_prev2[4 * i + 0] = -1.0;
    rg->mul_prev2[4 * i + 1] = d1[i];
    rg->mul_prev2[4 * i + 2] = -d_2 + 1.0;
    rg->mul_prev2[4 * i + 3] = d_2 * d1[i] - 2.0 * d1[i];
    rg->mul_in[4 * i + 0] = n2[i];
    rg->mul_in[4 * i + 1] = -d1[i] * n2[i];
    rg->mul_in[4 * i + 2] = d_2 * n2[i] - n2[i];
    rg->mul_in[4 * i + 3] = -d_2 * d1[i] * n2[i] + 2.0 * d1[i] * n2[i];
  }
  return rg;
}

namespace {

// Apply 1D horizontal scan to each row.
void FastGaussianHorizontal(const hwy::AlignedUniquePtr<RecursiveGaussian>& rg,
                            const ImageF& in, ThreadPool* pool,
                            ImageF* JXL_RESTRICT out) {
  JXL_CHECK(SameSize(in, *out));

  const intptr_t xsize = in.xsize();
  JXL_CHECK(RunOnPool(
      pool, 0, in.ysize(), ThreadPool::NoInit,
      [&](const uint32_t task, size_t /*thread*/) {
        const size_t y = task;
        const float* row_in = in.ConstRow(y);
        float* JXL_RESTRICT row_out = out->Row(y);
        FastGaussian1D(rg, row_in, xsize, row_out);
      },
      "FastGaussianHorizontal"));
}

}  // namespace

void FastGaussian(const hwy::AlignedUniquePtr<RecursiveGaussian>& rg,
                  const ImageF& in, ThreadPool* pool, ImageF* JXL_RESTRICT temp,
                  ImageF* JXL_RESTRICT out) {
  FastGaussianHorizontal(rg, in, pool, temp);
  HWY_DYNAMIC_DISPATCH(FastGaussianVertical)(rg, *temp, pool, out);
}

}  // namespace jxl
#endif  // HWY_ONCE
