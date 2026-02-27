// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/adaptive_quantization.h"

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

#include <algorithm>
#include <cmath>
#include <limits>
#include <string>
#include <vector>

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jpegli/adaptive_quantization.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jpegli/encode_internal.h"
#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/status.h"
HWY_BEFORE_NAMESPACE();
namespace jpegli {
namespace HWY_NAMESPACE {
namespace {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::AbsDiff;
using hwy::HWY_NAMESPACE::Add;
using hwy::HWY_NAMESPACE::And;
using hwy::HWY_NAMESPACE::Div;
using hwy::HWY_NAMESPACE::Floor;
using hwy::HWY_NAMESPACE::GetLane;
using hwy::HWY_NAMESPACE::Max;
using hwy::HWY_NAMESPACE::Min;
using hwy::HWY_NAMESPACE::Mul;
using hwy::HWY_NAMESPACE::MulAdd;
using hwy::HWY_NAMESPACE::NegMulAdd;
using hwy::HWY_NAMESPACE::Rebind;
using hwy::HWY_NAMESPACE::ShiftLeft;
using hwy::HWY_NAMESPACE::ShiftRight;
using hwy::HWY_NAMESPACE::Sqrt;
using hwy::HWY_NAMESPACE::Sub;
using hwy::HWY_NAMESPACE::ZeroIfNegative;

static constexpr float kInputScaling = 1.0f / 255.0f;

// Primary template: default to actual division.
template <typename T, class V>
struct FastDivision {
  HWY_INLINE V operator()(const V n, const V d) const { return n / d; }
};
// Partial specialization for float vectors.
template <class V>
struct FastDivision<float, V> {
  // One Newton-Raphson iteration.
  static HWY_INLINE V ReciprocalNR(const V x) {
    const auto rcp = ApproximateReciprocal(x);
    const auto sum = Add(rcp, rcp);
    const auto x_rcp = Mul(x, rcp);
    return NegMulAdd(x_rcp, rcp, sum);
  }

  V operator()(const V n, const V d) const {
#if 1  // Faster on SKX
    return Div(n, d);
#else
    return n * ReciprocalNR(d);
#endif
  }
};

// Approximates smooth functions via rational polynomials (i.e. dividing two
// polynomials). Evaluates polynomials via Horner's scheme, which is faster than
// Clenshaw recurrence for Chebyshev polynomials. LoadDup128 allows us to
// specify constants (replicated 4x) independently of the lane count.
template <size_t NP, size_t NQ, class D, class V, typename T>
HWY_INLINE HWY_MAYBE_UNUSED V EvalRationalPolynomial(const D d, const V x,
                                                     const T (&p)[NP],
                                                     const T (&q)[NQ]) {
  constexpr size_t kDegP = NP / 4 - 1;
  constexpr size_t kDegQ = NQ / 4 - 1;
  auto yp = LoadDup128(d, &p[kDegP * 4]);
  auto yq = LoadDup128(d, &q[kDegQ * 4]);
  // We use pointer arithmetic to refer to &p[(kDegP - n) * 4] to avoid a
  // compiler warning that the index is out of bounds since we are already
  // checking that it is not out of bounds with (kDegP >= n) and the access
  // will be optimized away. Similarly with q and kDegQ.
  HWY_FENCE;
  if (kDegP >= 1) yp = MulAdd(yp, x, LoadDup128(d, p + ((kDegP - 1) * 4)));
  if (kDegQ >= 1) yq = MulAdd(yq, x, LoadDup128(d, q + ((kDegQ - 1) * 4)));
  HWY_FENCE;
  if (kDegP >= 2) yp = MulAdd(yp, x, LoadDup128(d, p + ((kDegP - 2) * 4)));
  if (kDegQ >= 2) yq = MulAdd(yq, x, LoadDup128(d, q + ((kDegQ - 2) * 4)));
  HWY_FENCE;
  if (kDegP >= 3) yp = MulAdd(yp, x, LoadDup128(d, p + ((kDegP - 3) * 4)));
  if (kDegQ >= 3) yq = MulAdd(yq, x, LoadDup128(d, q + ((kDegQ - 3) * 4)));
  HWY_FENCE;
  if (kDegP >= 4) yp = MulAdd(yp, x, LoadDup128(d, p + ((kDegP - 4) * 4)));
  if (kDegQ >= 4) yq = MulAdd(yq, x, LoadDup128(d, q + ((kDegQ - 4) * 4)));
  HWY_FENCE;
  if (kDegP >= 5) yp = MulAdd(yp, x, LoadDup128(d, p + ((kDegP - 5) * 4)));
  if (kDegQ >= 5) yq = MulAdd(yq, x, LoadDup128(d, q + ((kDegQ - 5) * 4)));
  HWY_FENCE;
  if (kDegP >= 6) yp = MulAdd(yp, x, LoadDup128(d, p + ((kDegP - 6) * 4)));
  if (kDegQ >= 6) yq = MulAdd(yq, x, LoadDup128(d, q + ((kDegQ - 6) * 4)));
  HWY_FENCE;
  if (kDegP >= 7) yp = MulAdd(yp, x, LoadDup128(d, p + ((kDegP - 7) * 4)));
  if (kDegQ >= 7) yq = MulAdd(yq, x, LoadDup128(d, q + ((kDegQ - 7) * 4)));

  return FastDivision<T, V>()(yp, yq);
}

// Computes base-2 logarithm like std::log2. Undefined if negative / NaN.
// L1 error ~3.9E-6
template <class DF, class V>
V FastLog2f(const DF df, V x) {
  // 2,2 rational polynomial approximation of std::log1p(x) / std::log(2).
  HWY_ALIGN const float p[4 * (2 + 1)] = {HWY_REP4(-1.8503833400518310E-06f),
                                          HWY_REP4(1.4287160470083755E+00f),
                                          HWY_REP4(7.4245873327820566E-01f)};
  HWY_ALIGN const float q[4 * (2 + 1)] = {HWY_REP4(9.9032814277590719E-01f),
                                          HWY_REP4(1.0096718572241148E+00f),
                                          HWY_REP4(1.7409343003366853E-01f)};

  const Rebind<int32_t, DF> di;
  const auto x_bits = BitCast(di, x);

  // Range reduction to [-1/3, 1/3] - 3 integer, 2 float ops
  const auto exp_bits = Sub(x_bits, Set(di, 0x3f2aaaab));  // = 2/3
  // Shifted exponent = log2; also used to clear mantissa.
  const auto exp_shifted = ShiftRight<23>(exp_bits);
  const auto mantissa = BitCast(df, Sub(x_bits, ShiftLeft<23>(exp_shifted)));
  const auto exp_val = ConvertTo(df, exp_shifted);
  return Add(EvalRationalPolynomial(df, Sub(mantissa, Set(df, 1.0f)), p, q),
             exp_val);
}

// max relative error ~3e-7
template <class DF, class V>
V FastPow2f(const DF df, V x) {
  const Rebind<int32_t, DF> di;
  auto floorx = Floor(x);
  auto exp =
      BitCast(df, ShiftLeft<23>(Add(ConvertTo(di, floorx), Set(di, 127))));
  auto frac = Sub(x, floorx);
  auto num = Add(frac, Set(df, 1.01749063e+01));
  num = MulAdd(num, frac, Set(df, 4.88687798e+01));
  num = MulAdd(num, frac, Set(df, 9.85506591e+01));
  num = Mul(num, exp);
  auto den = MulAdd(frac, Set(df, 2.10242958e-01), Set(df, -2.22328856e-02));
  den = MulAdd(den, frac, Set(df, -1.94414990e+01));
  den = MulAdd(den, frac, Set(df, 9.85506633e+01));
  return Div(num, den);
}

inline float FastPow2f(float f) {
  HWY_CAPPED(float, 1) D;
  return GetLane(FastPow2f(D, Set(D, f)));
}

// The following functions modulate an exponent (out_val) and return the updated
// value. Their descriptor is limited to 8 lanes for 8x8 blocks.

template <class D, class V>
V ComputeMask(const D d, const V out_val) {
  const auto kBase = Set(d, -0.74174993f);
  const auto kMul4 = Set(d, 3.2353257320940401f);
  const auto kMul2 = Set(d, 12.906028311180409f);
  const auto kOffset2 = Set(d, 305.04035728311436f);
  const auto kMul3 = Set(d, 5.0220313103171232f);
  const auto kOffset3 = Set(d, 2.1925739705298404f);
  const auto kOffset4 = Mul(Set(d, 0.25f), kOffset3);
  const auto kMul0 = Set(d, 0.74760422233706747f);
  const auto k1 = Set(d, 1.0f);

  // Avoid division by zero.
  const auto v1 = Max(Mul(out_val, kMul0), Set(d, 1e-3f));
  const auto v2 = Div(k1, Add(v1, kOffset2));
  const auto v3 = Div(k1, MulAdd(v1, v1, kOffset3));
  const auto v4 = Div(k1, MulAdd(v1, v1, kOffset4));
  // TODO(jyrki):
  // A log or two here could make sense. In butteraugli we have effectively
  // log(log(x + C)) for this kind of use, as a single log is used in
  // saturating visual masking and here the modulation values are exponential,
  // another log would counter that.
  return Add(kBase, MulAdd(kMul4, v4, MulAdd(kMul2, v2, Mul(kMul3, v3))));
}

// mul and mul2 represent a scaling difference between jxl and butteraugli.
static const float kSGmul = 226.0480446705883f;
static const float kSGmul2 = 1.0f / 73.377132366608819f;
static const float kLog2 = 0.693147181f;
// Includes correction factor for std::log -> log2.
static const float kSGRetMul = kSGmul2 * 18.6580932135f * kLog2;
static const float kSGVOffset = 7.14672470003f;

template <bool invert, typename D, typename V>
V RatioOfDerivativesOfCubicRootToSimpleGamma(const D d, V v) {
  // The opsin space in jxl is the cubic root of photons, i.e., v * v * v
  // is related to the number of photons.
  //
  // SimpleGamma(v * v * v) is the psychovisual space in butteraugli.
  // This ratio allows quantization to move from jxl's opsin space to
  // butteraugli's log-gamma space.
  static const float kEpsilon = 1e-2;
  static const float kNumOffset = kEpsilon / kInputScaling / kInputScaling;
  static const float kNumMul = kSGRetMul * 3 * kSGmul;
  static const float kVOffset = (kSGVOffset * kLog2 + kEpsilon) / kInputScaling;
  static const float kDenMul = kLog2 * kSGmul * kInputScaling * kInputScaling;

  v = ZeroIfNegative(v);
  const auto num_mul = Set(d, kNumMul);
  const auto num_offset = Set(d, kNumOffset);
  const auto den_offset = Set(d, kVOffset);
  const auto den_mul = Set(d, kDenMul);

  const auto v2 = Mul(v, v);

  const auto num = MulAdd(num_mul, v2, num_offset);
  const auto den = MulAdd(Mul(den_mul, v), v2, den_offset);
  return invert ? Div(num, den) : Div(den, num);
}

template <bool invert = false>
static float RatioOfDerivativesOfCubicRootToSimpleGamma(float v) {
  using DScalar = HWY_CAPPED(float, 1);
  auto vscalar = Load(DScalar(), &v);
  return GetLane(
      RatioOfDerivativesOfCubicRootToSimpleGamma<invert>(DScalar(), vscalar));
}

// TODO(veluca): this function computes an approximation of the derivative of
// SimpleGamma with (f(x+eps)-f(x))/eps. Consider two-sided approximation or
// exact derivatives. For reference, SimpleGamma was:
/*
template <typename D, typename V>
V SimpleGamma(const D d, V v) {
  // A simple HDR compatible gamma function.
  const auto mul = Set(d, kSGmul);
  const auto kRetMul = Set(d, kSGRetMul);
  const auto kRetAdd = Set(d, kSGmul2 * -20.2789020414f);
  const auto kVOffset = Set(d, kSGVOffset);

  v *= mul;

  // This should happen rarely, but may lead to a NaN, which is rather
  // undesirable. Since negative photons don't exist we solve the NaNs by
  // clamping here.
  // TODO(veluca): with FastLog2f, this no longer leads to NaNs.
  v = ZeroIfNegative(v);
  return kRetMul * FastLog2f(d, v + kVOffset) + kRetAdd;
}
*/

template <class D, class V>
V GammaModulation(const D d, const size_t x, const size_t y,
                  const RowBuffer<float>& input, const V out_val) {
  static const float kBias = 0.16f / kInputScaling;
  static const float kScale = kInputScaling / 64.0f;
  auto overall_ratio = Zero(d);
  const auto bias = Set(d, kBias);
  const auto scale = Set(d, kScale);
  const float* const JXL_RESTRICT block_start = input.Row(y) + x;
  for (size_t dy = 0; dy < 8; ++dy) {
    const float* const JXL_RESTRICT row_in = block_start + dy * input.stride();
    for (size_t dx = 0; dx < 8; dx += Lanes(d)) {
      const auto iny = Add(Load(d, row_in + dx), bias);
      const auto ratio_g =
          RatioOfDerivativesOfCubicRootToSimpleGamma</*invert=*/true>(d, iny);
      overall_ratio = Add(overall_ratio, ratio_g);
    }
  }
  overall_ratio = Mul(SumOfLanes(d, overall_ratio), scale);
  // ideally -1.0, but likely optimal correction adds some entropy, so slightly
  // less than that.
  // ln(2) constant folded in because we want std::log but have FastLog2f.
  const auto kGam = Set(d, -0.15526878023684174f * 0.693147180559945f);
  return MulAdd(kGam, FastLog2f(d, overall_ratio), out_val);
}

// Change precision in 8x8 blocks that have high frequency content.
template <class D, class V>
V HfModulation(const D d, const size_t x, const size_t y,
               const RowBuffer<float>& input, const V out_val) {
  // Zero out the invalid differences for the rightmost value per row.
  const Rebind<uint32_t, D> du;
  HWY_ALIGN constexpr uint32_t kMaskRight[8] = {~0u, ~0u, ~0u, ~0u,
                                                ~0u, ~0u, ~0u, 0};

  auto sum = Zero(d);  // sum of absolute differences with right and below
  static const float kSumCoeff = -2.0052193233688884f * kInputScaling / 112.0;
  auto sumcoeff = Set(d, kSumCoeff);

  const float* const JXL_RESTRICT block_start = input.Row(y) + x;
  for (size_t dy = 0; dy < 8; ++dy) {
    const float* JXL_RESTRICT row_in = block_start + dy * input.stride();
    const float* JXL_RESTRICT row_in_next =
        dy == 7 ? row_in : row_in + input.stride();

    for (size_t dx = 0; dx < 8; dx += Lanes(d)) {
      const auto p = Load(d, row_in + dx);
      const auto pr = LoadU(d, row_in + dx + 1);
      const auto mask = BitCast(d, Load(du, kMaskRight + dx));
      sum = Add(sum, And(mask, AbsDiff(p, pr)));
      const auto pd = Load(d, row_in_next + dx);
      sum = Add(sum, AbsDiff(p, pd));
    }
  }

  sum = SumOfLanes(d, sum);
  return MulAdd(sum, sumcoeff, out_val);
}

void PerBlockModulations(const float y_quant_01, const RowBuffer<float>& input,
                         const size_t yb0, const size_t yblen,
                         RowBuffer<float>* aq_map) {
  static const float kAcQuant = 0.841f;
  float base_level = 0.48f * kAcQuant;
  float kDampenRampStart = 9.0f;
  float kDampenRampEnd = 65.0f;
  float dampen = 1.0f;
  if (y_quant_01 >= kDampenRampStart) {
    dampen = 1.0f - ((y_quant_01 - kDampenRampStart) /
                     (kDampenRampEnd - kDampenRampStart));
    if (dampen < 0) {
      dampen = 0;
    }
  }
  const float mul = kAcQuant * dampen;
  const float add = (1.0f - dampen) * base_level;
  for (size_t iy = 0; iy < yblen; iy++) {
    const size_t yb = yb0 + iy;
    const size_t y = yb * 8;
    float* const JXL_RESTRICT row_out = aq_map->Row(yb);
    const HWY_CAPPED(float, 8) df;
    for (size_t ix = 0; ix < aq_map->xsize(); ix++) {
      size_t x = ix * 8;
      auto out_val = Set(df, row_out[ix]);
      out_val = ComputeMask(df, out_val);
      out_val = HfModulation(df, x, y, input, out_val);
      out_val = GammaModulation(df, x, y, input, out_val);
      // We want multiplicative quantization field, so everything
      // until this point has been modulating the exponent.
      row_out[ix] = FastPow2f(GetLane(out_val) * 1.442695041f) * mul + add;
    }
  }
}

template <typename D, typename V>
V MaskingSqrt(const D d, V v) {
  static const float kLogOffset = 28;
  static const float kMul = 211.50759899638012f;
  const auto mul_v = Set(d, kMul * 1e8);
  const auto offset_v = Set(d, kLogOffset);
  return Mul(Set(d, 0.25f), Sqrt(MulAdd(v, Sqrt(mul_v), offset_v)));
}

template <typename V>
void Sort4(V& min0, V& min1, V& min2, V& min3) {
  const auto tmp0 = Min(min0, min1);
  const auto tmp1 = Max(min0, min1);
  const auto tmp2 = Min(min2, min3);
  const auto tmp3 = Max(min2, min3);
  const auto tmp4 = Max(tmp0, tmp2);
  const auto tmp5 = Min(tmp1, tmp3);
  min0 = Min(tmp0, tmp2);
  min1 = Min(tmp4, tmp5);
  min2 = Max(tmp4, tmp5);
  min3 = Max(tmp1, tmp3);
}

template <typename V>
void UpdateMin4(const V v, V& min0, V& min1, V& min2, V& min3) {
  const auto tmp0 = Max(min0, v);
  const auto tmp1 = Max(min1, tmp0);
  const auto tmp2 = Max(min2, tmp1);
  min0 = Min(min0, v);
  min1 = Min(min1, tmp0);
  min2 = Min(min2, tmp1);
  min3 = Min(min3, tmp2);
}

// Computes a linear combination of the 4 lowest values of the 3x3 neighborhood
// of each pixel. Output is downsampled 2x.
void FuzzyErosion(const RowBuffer<float>& pre_erosion, const size_t yb0,
                  const size_t yblen, RowBuffer<float>* tmp,
                  RowBuffer<float>* aq_map) {
  int xsize_blocks = aq_map->xsize();
  int xsize = pre_erosion.xsize();
  HWY_FULL(float) d;
  const auto mul0 = Set(d, 0.125f);
  const auto mul1 = Set(d, 0.075f);
  const auto mul2 = Set(d, 0.06f);
  const auto mul3 = Set(d, 0.05f);
  for (size_t iy = 0; iy < 2 * yblen; ++iy) {
    size_t y = 2 * yb0 + iy;
    const float* JXL_RESTRICT rowt = pre_erosion.Row(y - 1);
    const float* JXL_RESTRICT rowm = pre_erosion.Row(y);
    const float* JXL_RESTRICT rowb = pre_erosion.Row(y + 1);
    float* row_out = tmp->Row(y);
    for (int x = 0; x < xsize; x += Lanes(d)) {
      int xm1 = x - 1;
      int xp1 = x + 1;
      auto min0 = LoadU(d, rowm + x);
      auto min1 = LoadU(d, rowm + xm1);
      auto min2 = LoadU(d, rowm + xp1);
      auto min3 = LoadU(d, rowt + xm1);
      Sort4(min0, min1, min2, min3);
      UpdateMin4(LoadU(d, rowt + x), min0, min1, min2, min3);
      UpdateMin4(LoadU(d, rowt + xp1), min0, min1, min2, min3);
      UpdateMin4(LoadU(d, rowb + xm1), min0, min1, min2, min3);
      UpdateMin4(LoadU(d, rowb + x), min0, min1, min2, min3);
      UpdateMin4(LoadU(d, rowb + xp1), min0, min1, min2, min3);
      const auto v = Add(Add(Mul(mul0, min0), Mul(mul1, min1)),
                         Add(Mul(mul2, min2), Mul(mul3, min3)));
      Store(v, d, row_out + x);
    }
    if (iy % 2 == 1) {
      const float* JXL_RESTRICT row_out0 = tmp->Row(y - 1);
      float* JXL_RESTRICT aq_out = aq_map->Row(yb0 + iy / 2);
      for (int bx = 0, x = 0; bx < xsize_blocks; ++bx, x += 2) {
        aq_out[bx] =
            (row_out[x] + row_out[x + 1] + row_out0[x] + row_out0[x + 1]);
      }
    }
  }
}

void ComputePreErosion(const RowBuffer<float>& input, const size_t xsize,
                       const size_t y0, const size_t ylen, int border,
                       float* diff_buffer, RowBuffer<float>* pre_erosion) {
  const size_t xsize_out = xsize / 4;
  const size_t y0_out = y0 / 4;

  // The XYB gamma is 3.0 to be able to decode faster with two muls.
  // Butteraugli's gamma is matching the gamma of human eye, around 2.6.
  // We approximate the gamma difference by adding one cubic root into
  // the adaptive quantization. This gives us a total gamma of 2.6666
  // for quantization uses.
  static const float match_gamma_offset = 0.019 / kInputScaling;

  const HWY_CAPPED(float, 8) df;

  static const float limit = 0.2f;
  // Computes image (padded to multiple of 8x8) of local pixel differences.
  // Subsample both directions by 4.
  for (size_t iy = 0; iy < ylen; ++iy) {
    size_t y = y0 + iy;
    const float* row_in = input.Row(y);
    const float* row_in1 = input.Row(y + 1);
    const float* row_in2 = input.Row(y - 1);
    float* JXL_RESTRICT row_out = diff_buffer;
    const auto match_gamma_offset_v = Set(df, match_gamma_offset);
    const auto quarter = Set(df, 0.25f);
    for (size_t x = 0; x < xsize; x += Lanes(df)) {
      const auto in = LoadU(df, row_in + x);
      const auto in_r = LoadU(df, row_in + x + 1);
      const auto in_l = LoadU(df, row_in + x - 1);
      const auto in_t = LoadU(df, row_in2 + x);
      const auto in_b = LoadU(df, row_in1 + x);
      const auto base = Mul(quarter, Add(Add(in_r, in_l), Add(in_t, in_b)));
      const auto gammacv =
          RatioOfDerivativesOfCubicRootToSimpleGamma</*invert=*/false>(
              df, Add(in, match_gamma_offset_v));
      auto diff = Mul(gammacv, Sub(in, base));
      diff = Mul(diff, diff);
      diff = Min(diff, Set(df, limit));
      diff = MaskingSqrt(df, diff);
      if ((iy & 3) != 0) {
        diff = Add(diff, LoadU(df, row_out + x));
      }
      StoreU(diff, df, row_out + x);
    }
    if (iy % 4 == 3) {
      size_t y_out = y0_out + iy / 4;
      float* row_dout = pre_erosion->Row(y_out);
      for (size_t x = 0; x < xsize_out; x++) {
        row_dout[x] = (row_out[x * 4] + row_out[x * 4 + 1] +
                       row_out[x * 4 + 2] + row_out[x * 4 + 3]) *
                      0.25f;
      }
      pre_erosion->PadRow(y_out, xsize_out, border);
    }
  }
}

}  // namespace

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jpegli
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jpegli {
HWY_EXPORT(ComputePreErosion);
HWY_EXPORT(FuzzyErosion);
HWY_EXPORT(PerBlockModulations);

namespace {

static constexpr int kPreErosionBorder = 1;

}  // namespace

void ComputeAdaptiveQuantField(j_compress_ptr cinfo) {
  jpeg_comp_master* m = cinfo->master;
  if (!m->use_adaptive_quantization) {
    return;
  }
  int y_channel = cinfo->jpeg_color_space == JCS_RGB ? 1 : 0;
  jpeg_component_info* y_comp = &cinfo->comp_info[y_channel];
  int y_quant_01 = cinfo->quant_tbl_ptrs[y_comp->quant_tbl_no]->quantval[1];
  if (m->next_iMCU_row == 0) {
    m->input_buffer[y_channel].CopyRow(-1, 0, 1);
  }
  if (m->next_iMCU_row + 1 == cinfo->total_iMCU_rows) {
    size_t last_row = m->ysize_blocks * DCTSIZE - 1;
    m->input_buffer[y_channel].CopyRow(last_row + 1, last_row, 1);
  }
  const RowBuffer<float>& input = m->input_buffer[y_channel];
  const size_t xsize_blocks = y_comp->width_in_blocks;
  const size_t xsize = xsize_blocks * DCTSIZE;
  const size_t yb0 = m->next_iMCU_row * cinfo->max_v_samp_factor;
  const size_t yblen = cinfo->max_v_samp_factor;
  size_t y0 = yb0 * DCTSIZE;
  size_t ylen = cinfo->max_v_samp_factor * DCTSIZE;
  if (y0 == 0) {
    ylen += 4;
  } else {
    y0 += 4;
  }
  if (m->next_iMCU_row + 1 == cinfo->total_iMCU_rows) {
    ylen -= 4;
  }
  HWY_DYNAMIC_DISPATCH(ComputePreErosion)
  (input, xsize, y0, ylen, kPreErosionBorder, m->diff_buffer, &m->pre_erosion);
  if (y0 == 0) {
    m->pre_erosion.CopyRow(-1, 0, kPreErosionBorder);
  }
  if (m->next_iMCU_row + 1 == cinfo->total_iMCU_rows) {
    size_t last_row = m->ysize_blocks * 2 - 1;
    m->pre_erosion.CopyRow(last_row + 1, last_row, kPreErosionBorder);
  }
  HWY_DYNAMIC_DISPATCH(FuzzyErosion)
  (m->pre_erosion, yb0, yblen, &m->fuzzy_erosion_tmp, &m->quant_field);
  HWY_DYNAMIC_DISPATCH(PerBlockModulations)
  (y_quant_01, input, yb0, yblen, &m->quant_field);
  for (int y = 0; y < cinfo->max_v_samp_factor; ++y) {
    float* row = m->quant_field.Row(yb0 + y);
    for (size_t x = 0; x < xsize_blocks; ++x) {
      row[x] = std::max(0.0f, (0.6f / row[x]) - 1.0f);
    }
  }
}

}  // namespace jpegli
#endif  // HWY_ONCE
