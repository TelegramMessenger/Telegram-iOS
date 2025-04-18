// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_adaptive_quantization.h"

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

#include <algorithm>
#include <cmath>
#include <string>
#include <vector>

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/enc_adaptive_quantization.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jxl/ac_strategy.h"
#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/butteraugli/butteraugli.h"
#include "lib/jxl/coeff_order_fwd.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/color_management.h"
#include "lib/jxl/common.h"
#include "lib/jxl/convolve.h"
#include "lib/jxl/dec_cache.h"
#include "lib/jxl/dec_group.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/enc_butteraugli_comparator.h"
#include "lib/jxl/enc_cache.h"
#include "lib/jxl/enc_debug_image.h"
#include "lib/jxl/enc_group.h"
#include "lib/jxl/enc_modular.h"
#include "lib/jxl/enc_params.h"
#include "lib/jxl/enc_transforms-inl.h"
#include "lib/jxl/epf.h"
#include "lib/jxl/fast_math-inl.h"
#include "lib/jxl/gauss_blur.h"
#include "lib/jxl/image.h"
#include "lib/jxl/image_bundle.h"
#include "lib/jxl/image_ops.h"
#include "lib/jxl/opsin_params.h"
#include "lib/jxl/quant_weights.h"

// Set JXL_DEBUG_ADAPTIVE_QUANTIZATION to 1 to enable debugging.
#ifndef JXL_DEBUG_ADAPTIVE_QUANTIZATION
#define JXL_DEBUG_ADAPTIVE_QUANTIZATION 0
#endif

HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {
namespace {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::AbsDiff;
using hwy::HWY_NAMESPACE::Add;
using hwy::HWY_NAMESPACE::And;
using hwy::HWY_NAMESPACE::Max;
using hwy::HWY_NAMESPACE::Rebind;
using hwy::HWY_NAMESPACE::Sqrt;
using hwy::HWY_NAMESPACE::ZeroIfNegative;

// The following functions modulate an exponent (out_val) and return the updated
// value. Their descriptor is limited to 8 lanes for 8x8 blocks.

// Hack for mask estimation. Eventually replace this code with butteraugli's
// masking.
float ComputeMaskForAcStrategyUse(const float out_val) {
  const float kMul = 1.0f;
  const float kOffset = 0.001f;
  return kMul / (out_val + kOffset);
}

template <class D, class V>
V ComputeMask(const D d, const V out_val) {
  const auto kBase = Set(d, -0.76471879237038032f);
  const auto kMul4 = Set(d, 4.4585596705216615f);
  const auto kMul2 = Set(d, 17.282053892620215f);
  const auto kOffset2 = Set(d, 302.36961315317848f);
  const auto kMul3 = Set(d, 7.0561261998705858f);
  const auto kOffset3 = Set(d, 2.3179635626140773f);
  const auto kOffset4 = Mul(Set(d, 0.25f), kOffset3);
  const auto kMul0 = Set(d, 0.80061762862741759f);
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
static const float kSGmul = 226.77216153508914f;
static const float kSGmul2 = 1.0f / 73.377132366608819f;
static const float kLog2 = 0.693147181f;
// Includes correction factor for std::log -> log2.
static const float kSGRetMul = kSGmul2 * 18.6580932135f * kLog2;
static const float kSGVOffset = 7.7825991679894591f;

template <bool invert, typename D, typename V>
V RatioOfDerivativesOfCubicRootToSimpleGamma(const D d, V v) {
  // The opsin space in jxl is the cubic root of photons, i.e., v * v * v
  // is related to the number of photons.
  //
  // SimpleGamma(v * v * v) is the psychovisual space in butteraugli.
  // This ratio allows quantization to move from jxl's opsin space to
  // butteraugli's log-gamma space.
  float kEpsilon = 1e-2;
  v = ZeroIfNegative(v);
  const auto kNumMul = Set(d, kSGRetMul * 3 * kSGmul);
  const auto kVOffset = Set(d, kSGVOffset * kLog2 + kEpsilon);
  const auto kDenMul = Set(d, kLog2 * kSGmul);

  const auto v2 = Mul(v, v);

  const auto num = MulAdd(kNumMul, v2, Set(d, kEpsilon));
  const auto den = MulAdd(Mul(kDenMul, v), v2, kVOffset);
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
                  const ImageF& xyb_x, const ImageF& xyb_y, const V out_val) {
  const float kBias = 0.16f;
  JXL_DASSERT(kBias > kOpsinAbsorbanceBias[0]);
  JXL_DASSERT(kBias > kOpsinAbsorbanceBias[1]);
  JXL_DASSERT(kBias > kOpsinAbsorbanceBias[2]);
  auto overall_ratio = Zero(d);
  auto bias = Set(d, kBias);
  auto half = Set(d, 0.5f);
  for (size_t dy = 0; dy < 8; ++dy) {
    const float* const JXL_RESTRICT row_in_x = xyb_x.Row(y + dy);
    const float* const JXL_RESTRICT row_in_y = xyb_y.Row(y + dy);
    for (size_t dx = 0; dx < 8; dx += Lanes(d)) {
      const auto iny = Add(Load(d, row_in_y + x + dx), bias);
      const auto inx = Load(d, row_in_x + x + dx);
      const auto r = Sub(iny, inx);
      const auto g = Add(iny, inx);
      const auto ratio_r =
          RatioOfDerivativesOfCubicRootToSimpleGamma</*invert=*/true>(d, r);
      const auto ratio_g =
          RatioOfDerivativesOfCubicRootToSimpleGamma</*invert=*/true>(d, g);
      const auto avg_ratio = Mul(half, Add(ratio_r, ratio_g));

      overall_ratio = Add(overall_ratio, avg_ratio);
    }
  }
  overall_ratio = Mul(SumOfLanes(d, overall_ratio), Set(d, 1.0f / 64));
  // ideally -1.0, but likely optimal correction adds some entropy, so slightly
  // less than that.
  // ln(2) constant folded in because we want std::log but have FastLog2f.
  const auto kGam = Set(d, -0.15526878023684174f * 0.693147180559945f);
  return MulAdd(kGam, FastLog2f(d, overall_ratio), out_val);
}

template <class D, class V>
V ColorModulation(const D d, const size_t x, const size_t y,
                  const ImageF& xyb_x, const ImageF& xyb_y, const ImageF& xyb_b,
                  const double butteraugli_target, V out_val) {
  static const float kStrengthMul = 4.2456542701250122f;
  static const float kRedRampStart = 0.18748564245760829f;
  static const float kRedRampLength = 0.16701783842516479f;
  static const float kBlueRampLength = 0.16117602661852037f;
  static const float kBlueRampStart = 0.47897504338287333f;
  const float strength = kStrengthMul * (1.0f - 0.15f * butteraugli_target);
  if (strength < 0) {
    return out_val;
  }
  // x values are smaller than y and b values, need to take the difference into
  // account.
  const float red_strength = strength * 6.0f;
  const float blue_strength = strength;
  {
    // Reduce some bits from areas not blue or red.
    const float offset = strength * -0.007;  // 9174542291185913f;
    out_val = Add(out_val, Set(d, offset));
  }
  // Calculate how much of the 8x8 block is covered with blue or red.
  auto blue_coverage = Zero(d);
  auto red_coverage = Zero(d);
  auto bias_y = Set(d, 0.2f);
  auto bias_y_add = Set(d, 0.1f);
  for (size_t dy = 0; dy < 8; ++dy) {
    const float* const JXL_RESTRICT row_in_x = xyb_x.Row(y + dy);
    const float* const JXL_RESTRICT row_in_y = xyb_y.Row(y + dy);
    const float* const JXL_RESTRICT row_in_b = xyb_b.Row(y + dy);
    for (size_t dx = 0; dx < 8; dx += Lanes(d)) {
      const auto pixel_y = Load(d, row_in_y + x + dx);
      // Estimate redness-greeness relative to the intensity.
      const auto pixel_xpy = Div(Abs(Load(d, row_in_x + x + dx)),
                                 Max(Add(bias_y_add, pixel_y), bias_y));
      const auto pixel_x =
          Max(Set(d, 0.0f), Sub(pixel_xpy, Set(d, kRedRampStart)));
      const auto pixel_b =
          Max(Set(d, 0.0f), Sub(Load(d, row_in_b + x + dx),
                                Add(pixel_y, Set(d, kBlueRampStart))));
      const auto blue_slope = Min(pixel_b, Set(d, kBlueRampLength));
      const auto red_slope = Min(pixel_x, Set(d, kRedRampLength));
      red_coverage = Add(red_coverage, red_slope);
      blue_coverage = Add(blue_coverage, blue_slope);
    }
  }

  // Saturate when the high red or high blue coverage is above a level.
  // The idea here is that if a certain fraction of the block is red or
  // blue we consider as if it was fully red or blue.
  static const float ratio = 28.0f;  // out of 64 pixels.

  auto overall_red_coverage = SumOfLanes(d, red_coverage);
  overall_red_coverage =
      Min(overall_red_coverage, Set(d, ratio * kRedRampLength));
  overall_red_coverage =
      Mul(overall_red_coverage, Set(d, red_strength / ratio));

  auto overall_blue_coverage = SumOfLanes(d, blue_coverage);
  overall_blue_coverage =
      Min(overall_blue_coverage, Set(d, ratio * kBlueRampLength));
  overall_blue_coverage =
      Mul(overall_blue_coverage, Set(d, blue_strength / ratio));

  return Add(overall_red_coverage, Add(overall_blue_coverage, out_val));
}

// Change precision in 8x8 blocks that have high frequency content.
template <class D, class V>
V HfModulation(const D d, const size_t x, const size_t y, const ImageF& xyb,
               const V out_val) {
  // Zero out the invalid differences for the rightmost value per row.
  const Rebind<uint32_t, D> du;
  HWY_ALIGN constexpr uint32_t kMaskRight[kBlockDim] = {~0u, ~0u, ~0u, ~0u,
                                                        ~0u, ~0u, ~0u, 0};

  auto sum = Zero(d);  // sum of absolute differences with right and below

  static const float valmin = 0.52489909479039587f;
  auto valminv = Set(d, valmin);
  for (size_t dy = 0; dy < 8; ++dy) {
    const float* JXL_RESTRICT row_in = xyb.Row(y + dy) + x;
    const float* JXL_RESTRICT row_in_next =
        dy == 7 ? row_in : xyb.Row(y + dy + 1) + x;

    // In SCALAR, there is no guarantee of having extra row padding.
    // Hence, we need to ensure we don't access pixels outside the row itself.
    // In SIMD modes, however, rows are padded, so it's safe to access one
    // garbage value after the row. The vector then gets masked with kMaskRight
    // to remove the influence of that value.
#if HWY_TARGET != HWY_SCALAR
    for (size_t dx = 0; dx < 8; dx += Lanes(d)) {
#else
    for (size_t dx = 0; dx < 7; dx += Lanes(d)) {
#endif
      const auto p = Load(d, row_in + dx);
      const auto pr = LoadU(d, row_in + dx + 1);
      const auto mask = BitCast(d, Load(du, kMaskRight + dx));
      sum = Add(sum, And(mask, Min(valminv, AbsDiff(p, pr))));

      const auto pd = Load(d, row_in_next + dx);
      sum = Add(sum, Min(valminv, AbsDiff(p, pd)));
    }
#if HWY_TARGET == HWY_SCALAR
    const auto p = Load(d, row_in + 7);
    const auto pd = Load(d, row_in_next + 7);
    sum = Add(sum, Min(valminv, AbsDiff(p, pd)));
#endif
  }
  // more negative value gives more bpp
  static const float kOffset = -2.6545897672771526;
  static const float kMul = -0.049868161744916512;

  sum = SumOfLanes(d, sum);
  float scalar_sum = GetLane(sum);
  static const float maxsum = 7.9076877647025947f;
  static const float minsum = 0.53640540945659809f;
  scalar_sum = std::min(maxsum, scalar_sum);
  scalar_sum = std::max(minsum, scalar_sum);
  scalar_sum += kOffset;
  scalar_sum *= kMul;
  return Add(Set(d, scalar_sum), out_val);
}

void PerBlockModulations(const float butteraugli_target, const ImageF& xyb_x,
                         const ImageF& xyb_y, const ImageF& xyb_b,
                         const float scale, const Rect& rect, ImageF* out) {
  JXL_ASSERT(SameSize(xyb_x, xyb_y));
  JXL_ASSERT(DivCeil(xyb_x.xsize(), kBlockDim) == out->xsize());
  JXL_ASSERT(DivCeil(xyb_x.ysize(), kBlockDim) == out->ysize());

  float base_level = 0.48f * scale;
  float kDampenRampStart = 2.0f;
  float kDampenRampEnd = 14.0f;
  float dampen = 1.0f;
  if (butteraugli_target >= kDampenRampStart) {
    dampen = 1.0f - ((butteraugli_target - kDampenRampStart) /
                     (kDampenRampEnd - kDampenRampStart));
    if (dampen < 0) {
      dampen = 0;
    }
  }
  const float mul = scale * dampen;
  const float add = (1.0f - dampen) * base_level;
  for (size_t iy = rect.y0(); iy < rect.y0() + rect.ysize(); iy++) {
    const size_t y = iy * 8;
    float* const JXL_RESTRICT row_out = out->Row(iy);
    const HWY_CAPPED(float, kBlockDim) df;
    for (size_t ix = rect.x0(); ix < rect.x0() + rect.xsize(); ix++) {
      size_t x = ix * 8;
      auto out_val = Set(df, row_out[ix]);
      out_val = ComputeMask(df, out_val);
      out_val = HfModulation(df, x, y, xyb_y, out_val);
      out_val = ColorModulation(df, x, y, xyb_x, xyb_y, xyb_b,
                                butteraugli_target, out_val);
      out_val = GammaModulation(df, x, y, xyb_x, xyb_y, out_val);
      // We want multiplicative quantization field, so everything
      // until this point has been modulating the exponent.
      row_out[ix] = FastPow2f(GetLane(out_val) * 1.442695041f) * mul + add;
    }
  }
}

template <typename D, typename V>
V MaskingSqrt(const D d, V v) {
  static const float kLogOffset = 27.97044946785558f;
  static const float kMul = 211.53333281566171f;
  const auto mul_v = Set(d, kMul * 1e8);
  const auto offset_v = Set(d, kLogOffset);
  return Mul(Set(d, 0.25f), Sqrt(MulAdd(v, Sqrt(mul_v), offset_v)));
}

float MaskingSqrt(const float v) {
  using DScalar = HWY_CAPPED(float, 1);
  auto vscalar = Load(DScalar(), &v);
  return GetLane(MaskingSqrt(DScalar(), vscalar));
}

void StoreMin4(const float v, float& min0, float& min1, float& min2,
               float& min3) {
  if (v < min3) {
    if (v < min0) {
      min3 = min2;
      min2 = min1;
      min1 = min0;
      min0 = v;
    } else if (v < min1) {
      min3 = min2;
      min2 = min1;
      min1 = v;
    } else if (v < min2) {
      min3 = min2;
      min2 = v;
    } else {
      min3 = v;
    }
  }
}

// Look for smooth areas near the area of degradation.
// If the areas are generally smooth, don't do masking.
// Output is downsampled 2x.
void FuzzyErosion(const Rect& from_rect, const ImageF& from,
                  const Rect& to_rect, ImageF* to) {
  const size_t xsize = from.xsize();
  const size_t ysize = from.ysize();
  constexpr int kStep = 1;
  static_assert(kStep == 1, "Step must be 1");
  JXL_ASSERT(to_rect.xsize() * 2 == from_rect.xsize());
  JXL_ASSERT(to_rect.ysize() * 2 == from_rect.ysize());
  for (size_t fy = 0; fy < from_rect.ysize(); ++fy) {
    size_t y = fy + from_rect.y0();
    size_t ym1 = y >= kStep ? y - kStep : y;
    size_t yp1 = y + kStep < ysize ? y + kStep : y;
    const float* rowt = from.Row(ym1);
    const float* row = from.Row(y);
    const float* rowb = from.Row(yp1);
    float* row_out = to_rect.Row(to, fy / 2);
    for (size_t fx = 0; fx < from_rect.xsize(); ++fx) {
      size_t x = fx + from_rect.x0();
      size_t xm1 = x >= kStep ? x - kStep : x;
      size_t xp1 = x + kStep < xsize ? x + kStep : x;
      float min0 = row[x];
      float min1 = row[xm1];
      float min2 = row[xp1];
      float min3 = rowt[xm1];
      // Sort the first four values.
      if (min0 > min1) std::swap(min0, min1);
      if (min0 > min2) std::swap(min0, min2);
      if (min0 > min3) std::swap(min0, min3);
      if (min1 > min2) std::swap(min1, min2);
      if (min1 > min3) std::swap(min1, min3);
      if (min2 > min3) std::swap(min2, min3);
      // The remaining five values of a 3x3 neighbourhood.
      StoreMin4(rowt[x], min0, min1, min2, min3);
      StoreMin4(rowt[xp1], min0, min1, min2, min3);
      StoreMin4(rowb[xm1], min0, min1, min2, min3);
      StoreMin4(rowb[x], min0, min1, min2, min3);
      StoreMin4(rowb[xp1], min0, min1, min2, min3);
      static const float kMul0 = 0.125f;
      static const float kMul1 = 0.075f;
      static const float kMul2 = 0.06f;
      static const float kMul3 = 0.05f;
      float v = kMul0 * min0 + kMul1 * min1 + kMul2 * min2 + kMul3 * min3;
      if (fx % 2 == 0 && fy % 2 == 0) {
        row_out[fx / 2] = v;
      } else {
        row_out[fx / 2] += v;
      }
    }
  }
}

struct AdaptiveQuantizationImpl {
  void Init(const Image3F& xyb) {
    JXL_DASSERT(xyb.xsize() % kBlockDim == 0);
    JXL_DASSERT(xyb.ysize() % kBlockDim == 0);
    const size_t xsize = xyb.xsize();
    const size_t ysize = xyb.ysize();
    aq_map = ImageF(xsize / kBlockDim, ysize / kBlockDim);
  }
  void PrepareBuffers(size_t num_threads) {
    diff_buffer = ImageF(kEncTileDim + 8, num_threads);
    for (size_t i = pre_erosion.size(); i < num_threads; i++) {
      pre_erosion.emplace_back(kEncTileDimInBlocks * 2 + 2,
                               kEncTileDimInBlocks * 2 + 2);
    }
  }

  void ComputeTile(float butteraugli_target, float scale, const Image3F& xyb,
                   const Rect& rect, const int thread, ImageF* mask) {
    const size_t xsize = xyb.xsize();
    const size_t ysize = xyb.ysize();

    // The XYB gamma is 3.0 to be able to decode faster with two muls.
    // Butteraugli's gamma is matching the gamma of human eye, around 2.6.
    // We approximate the gamma difference by adding one cubic root into
    // the adaptive quantization. This gives us a total gamma of 2.6666
    // for quantization uses.
    const float match_gamma_offset = 0.019;

    const HWY_FULL(float) df;

    size_t y_start = rect.y0() * 8;
    size_t y_end = y_start + rect.ysize() * 8;

    size_t x0 = rect.x0() * 8;
    size_t x1 = x0 + rect.xsize() * 8;
    if (x0 != 0) x0 -= 4;
    if (x1 != xyb.xsize()) x1 += 4;
    if (y_start != 0) y_start -= 4;
    if (y_end != xyb.ysize()) y_end += 4;
    pre_erosion[thread].ShrinkTo((x1 - x0) / 4, (y_end - y_start) / 4);

    static const float limit = 0.2f;
    // Computes image (padded to multiple of 8x8) of local pixel differences.
    // Subsample both directions by 4.
    for (size_t y = y_start; y < y_end; ++y) {
      size_t y2 = y + 1 < ysize ? y + 1 : y;
      size_t y1 = y > 0 ? y - 1 : y;

      const float* row_in = xyb.PlaneRow(1, y);
      const float* row_in1 = xyb.PlaneRow(1, y1);
      const float* row_in2 = xyb.PlaneRow(1, y2);
      float* JXL_RESTRICT row_out = diff_buffer.Row(thread);

      auto scalar_pixel = [&](size_t x) {
        const size_t x2 = x + 1 < xsize ? x + 1 : x;
        const size_t x1 = x > 0 ? x - 1 : x;
        const float base =
            0.25f * (row_in2[x] + row_in1[x] + row_in[x1] + row_in[x2]);
        const float gammac = RatioOfDerivativesOfCubicRootToSimpleGamma(
            row_in[x] + match_gamma_offset);
        float diff = gammac * (row_in[x] - base);
        diff *= diff;
        if (diff >= limit) {
          diff = limit;
        }
        diff = MaskingSqrt(diff);
        if ((y % 4) != 0) {
          row_out[x - x0] += diff;
        } else {
          row_out[x - x0] = diff;
        }
      };

      size_t x = x0;
      // First pixel of the row.
      if (x0 == 0) {
        scalar_pixel(x0);
        ++x;
      }
      // SIMD
      const auto match_gamma_offset_v = Set(df, match_gamma_offset);
      const auto quarter = Set(df, 0.25f);
      for (; x + 1 + Lanes(df) < x1; x += Lanes(df)) {
        const auto in = LoadU(df, row_in + x);
        const auto in_r = LoadU(df, row_in + x + 1);
        const auto in_l = LoadU(df, row_in + x - 1);
        const auto in_t = LoadU(df, row_in2 + x);
        const auto in_b = LoadU(df, row_in1 + x);
        auto base = Mul(quarter, Add(Add(in_r, in_l), Add(in_t, in_b)));
        auto gammacv =
            RatioOfDerivativesOfCubicRootToSimpleGamma</*invert=*/false>(
                df, Add(in, match_gamma_offset_v));
        auto diff = Mul(gammacv, Sub(in, base));
        diff = Mul(diff, diff);
        diff = Min(diff, Set(df, limit));
        diff = MaskingSqrt(df, diff);
        if ((y & 3) != 0) {
          diff = Add(diff, LoadU(df, row_out + x - x0));
        }
        StoreU(diff, df, row_out + x - x0);
      }
      // Scalar
      for (; x < x1; ++x) {
        scalar_pixel(x);
      }
      if (y % 4 == 3) {
        float* row_dout = pre_erosion[thread].Row((y - y_start) / 4);
        for (size_t x = 0; x < (x1 - x0) / 4; x++) {
          row_dout[x] = (row_out[x * 4] + row_out[x * 4 + 1] +
                         row_out[x * 4 + 2] + row_out[x * 4 + 3]) *
                        0.25f;
        }
      }
    }
    Rect from_rect(x0 % 8 == 0 ? 0 : 1, y_start % 8 == 0 ? 0 : 1,
                   rect.xsize() * 2, rect.ysize() * 2);
    FuzzyErosion(from_rect, pre_erosion[thread], rect, &aq_map);
    for (size_t y = 0; y < rect.ysize(); ++y) {
      const float* aq_map_row = rect.ConstRow(aq_map, y);
      float* mask_row = rect.Row(mask, y);
      for (size_t x = 0; x < rect.xsize(); ++x) {
        mask_row[x] = ComputeMaskForAcStrategyUse(aq_map_row[x]);
      }
    }
    PerBlockModulations(butteraugli_target, xyb.Plane(0), xyb.Plane(1),
                        xyb.Plane(2), scale, rect, &aq_map);
  }
  std::vector<ImageF> pre_erosion;
  ImageF aq_map;
  ImageF diff_buffer;
};

ImageF AdaptiveQuantizationMap(const float butteraugli_target,
                               const Image3F& xyb,
                               const FrameDimensions& frame_dim, float scale,
                               ThreadPool* pool, ImageF* mask) {
  AdaptiveQuantizationImpl impl;
  impl.Init(xyb);
  *mask = ImageF(frame_dim.xsize_blocks, frame_dim.ysize_blocks);
  JXL_CHECK(RunOnPool(
      pool, 0,
      DivCeil(frame_dim.xsize_blocks, kEncTileDimInBlocks) *
          DivCeil(frame_dim.ysize_blocks, kEncTileDimInBlocks),
      [&](const size_t num_threads) {
        impl.PrepareBuffers(num_threads);
        return true;
      },
      [&](const uint32_t tid, const size_t thread) {
        size_t n_enc_tiles =
            DivCeil(frame_dim.xsize_blocks, kEncTileDimInBlocks);
        size_t tx = tid % n_enc_tiles;
        size_t ty = tid / n_enc_tiles;
        size_t by0 = ty * kEncTileDimInBlocks;
        size_t by1 =
            std::min((ty + 1) * kEncTileDimInBlocks, frame_dim.ysize_blocks);
        size_t bx0 = tx * kEncTileDimInBlocks;
        size_t bx1 =
            std::min((tx + 1) * kEncTileDimInBlocks, frame_dim.xsize_blocks);
        Rect r(bx0, by0, bx1 - bx0, by1 - by0);
        impl.ComputeTile(butteraugli_target, scale, xyb, r, thread, mask);
      },
      "AQ DiffPrecompute"));

  return std::move(impl).aq_map;
}

}  // namespace

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {
HWY_EXPORT(AdaptiveQuantizationMap);

namespace {

// If true, prints the quantization maps at each iteration.
constexpr bool FLAGS_dump_quant_state = false;

void DumpHeatmap(const CompressParams& cparams, const AuxOut* aux_out,
                 const std::string& label, const ImageF& image,
                 float good_threshold, float bad_threshold) {
  if (JXL_DEBUG_ADAPTIVE_QUANTIZATION) {
    Image3F heatmap = CreateHeatMapImage(image, good_threshold, bad_threshold);
    char filename[200];
    snprintf(filename, sizeof(filename), "%s%05d", label.c_str(),
             aux_out->num_butteraugli_iters);
    DumpImage(cparams, filename, heatmap);
  }
}

void DumpHeatmaps(const CompressParams& cparams, const AuxOut* aux_out,
                  float ba_target, const ImageF& quant_field,
                  const ImageF& tile_heatmap, const ImageF& bt_diffmap) {
  if (JXL_DEBUG_ADAPTIVE_QUANTIZATION) {
    if (!WantDebugOutput(cparams)) return;
    ImageF inv_qmap(quant_field.xsize(), quant_field.ysize());
    for (size_t y = 0; y < quant_field.ysize(); ++y) {
      const float* JXL_RESTRICT row_q = quant_field.ConstRow(y);
      float* JXL_RESTRICT row_inv_q = inv_qmap.Row(y);
      for (size_t x = 0; x < quant_field.xsize(); ++x) {
        row_inv_q[x] = 1.0f / row_q[x];  // never zero
      }
    }
    DumpHeatmap(cparams, aux_out, "quant_heatmap", inv_qmap, 4.0f * ba_target,
                6.0f * ba_target);
    DumpHeatmap(cparams, aux_out, "tile_heatmap", tile_heatmap, ba_target,
                1.5f * ba_target);
    // matches heat maps produced by the command line tool.
    DumpHeatmap(cparams, aux_out, "bt_diffmap", bt_diffmap,
                ButteraugliFuzzyInverse(1.5), ButteraugliFuzzyInverse(0.5));
  }
}

ImageF TileDistMap(const ImageF& distmap, int tile_size, int margin,
                   const AcStrategyImage& ac_strategy) {
  const int tile_xsize = (distmap.xsize() + tile_size - 1) / tile_size;
  const int tile_ysize = (distmap.ysize() + tile_size - 1) / tile_size;
  ImageF tile_distmap(tile_xsize, tile_ysize);
  size_t distmap_stride = tile_distmap.PixelsPerRow();
  for (int tile_y = 0; tile_y < tile_ysize; ++tile_y) {
    AcStrategyRow ac_strategy_row = ac_strategy.ConstRow(tile_y);
    float* JXL_RESTRICT dist_row = tile_distmap.Row(tile_y);
    for (int tile_x = 0; tile_x < tile_xsize; ++tile_x) {
      AcStrategy acs = ac_strategy_row[tile_x];
      if (!acs.IsFirstBlock()) continue;
      int this_tile_xsize = acs.covered_blocks_x() * tile_size;
      int this_tile_ysize = acs.covered_blocks_y() * tile_size;
      int y_begin = std::max<int>(0, tile_size * tile_y - margin);
      int y_end = std::min<int>(distmap.ysize(),
                                tile_size * tile_y + this_tile_ysize + margin);
      int x_begin = std::max<int>(0, tile_size * tile_x - margin);
      int x_end = std::min<int>(distmap.xsize(),
                                tile_size * tile_x + this_tile_xsize + margin);
      float dist_norm = 0.0;
      double pixels = 0;
      for (int y = y_begin; y < y_end; ++y) {
        float ymul = 1.0;
        constexpr float kBorderMul = 0.98f;
        constexpr float kCornerMul = 0.7f;
        if (margin != 0 && (y == y_begin || y == y_end - 1)) {
          ymul = kBorderMul;
        }
        const float* const JXL_RESTRICT row = distmap.Row(y);
        for (int x = x_begin; x < x_end; ++x) {
          float xmul = ymul;
          if (margin != 0 && (x == x_begin || x == x_end - 1)) {
            if (xmul == 1.0) {
              xmul = kBorderMul;
            } else {
              xmul = kCornerMul;
            }
          }
          float v = row[x];
          v *= v;
          v *= v;
          v *= v;
          v *= v;
          dist_norm += xmul * v;
          pixels += xmul;
        }
      }
      if (pixels == 0) pixels = 1;
      // 16th norm is less than the max norm, we reduce the difference
      // with this normalization factor.
      constexpr float kTileNorm = 1.2f;
      const float tile_dist =
          kTileNorm * std::pow(dist_norm / pixels, 1.0f / 16.0f);
      dist_row[tile_x] = tile_dist;
      for (size_t iy = 0; iy < acs.covered_blocks_y(); iy++) {
        for (size_t ix = 0; ix < acs.covered_blocks_x(); ix++) {
          dist_row[tile_x + distmap_stride * iy + ix] = tile_dist;
        }
      }
    }
  }
  return tile_distmap;
}

static const float kDcQuantPow = 0.83;
static const float kDcQuant = 1.095924047623553f;
static const float kAcQuant = 0.7635;

// Computes the decoded image for a given set of compression parameters.
ImageBundle RoundtripImage(const Image3F& opsin, PassesEncoderState* enc_state,
                           const JxlCmsInterface& cms, ThreadPool* pool) {
  std::unique_ptr<PassesDecoderState> dec_state =
      jxl::make_unique<PassesDecoderState>();
  JXL_CHECK(dec_state->output_encoding_info.SetFromMetadata(
      *enc_state->shared.metadata));
  dec_state->shared = &enc_state->shared;
  JXL_ASSERT(opsin.ysize() % kBlockDim == 0);

  const size_t xsize_groups = DivCeil(opsin.xsize(), kGroupDim);
  const size_t ysize_groups = DivCeil(opsin.ysize(), kGroupDim);
  const size_t num_groups = xsize_groups * ysize_groups;

  size_t num_special_frames = enc_state->special_frames.size();

  std::unique_ptr<ModularFrameEncoder> modular_frame_encoder =
      jxl::make_unique<ModularFrameEncoder>(enc_state->shared.frame_header,
                                            enc_state->cparams);
  JXL_CHECK(InitializePassesEncoder(opsin, cms, pool, enc_state,
                                    modular_frame_encoder.get(), nullptr));
  JXL_CHECK(dec_state->Init());
  JXL_CHECK(dec_state->InitForAC(pool));

  ImageBundle decoded(&enc_state->shared.metadata->m);
  decoded.origin = enc_state->shared.frame_header.frame_origin;
  decoded.SetFromImage(Image3F(opsin.xsize(), opsin.ysize()),
                       dec_state->output_encoding_info.color_encoding);

  PassesDecoderState::PipelineOptions options;
  options.use_slow_render_pipeline = false;
  options.coalescing = false;
  options.render_spotcolors = false;

  // Same as dec_state->shared->frame_header.nonserialized_metadata->m
  const ImageMetadata& metadata = *decoded.metadata();

  JXL_CHECK(dec_state->PreparePipeline(&decoded, options));

  hwy::AlignedUniquePtr<GroupDecCache[]> group_dec_caches;
  const auto allocate_storage = [&](const size_t num_threads) -> Status {
    JXL_RETURN_IF_ERROR(
        dec_state->render_pipeline->PrepareForThreads(num_threads,
                                                      /*use_group_ids=*/false));
    group_dec_caches = hwy::MakeUniqueAlignedArray<GroupDecCache>(num_threads);
    return true;
  };
  const auto process_group = [&](const uint32_t group_index,
                                 const size_t thread) {
    if (dec_state->shared->frame_header.loop_filter.epf_iters > 0) {
      ComputeSigma(dec_state->shared->BlockGroupRect(group_index),
                   dec_state.get());
    }
    RenderPipelineInput input =
        dec_state->render_pipeline->GetInputBuffers(group_index, thread);
    JXL_CHECK(DecodeGroupForRoundtrip(
        enc_state->coeffs, group_index, dec_state.get(),
        &group_dec_caches[thread], thread, input, &decoded, nullptr));
    for (size_t c = 0; c < metadata.num_extra_channels; c++) {
      std::pair<ImageF*, Rect> ri = input.GetBuffer(3 + c);
      FillPlane(0.0f, ri.first, ri.second);
    }
    input.Done();
  };
  JXL_CHECK(RunOnPool(pool, 0, num_groups, allocate_storage, process_group,
                      "AQ loop"));

  // Ensure we don't create any new special frames.
  enc_state->special_frames.resize(num_special_frames);

  return decoded;
}

constexpr int kMaxButteraugliIters = 4;

void FindBestQuantization(const ImageBundle& linear, const Image3F& opsin,
                          PassesEncoderState* enc_state,
                          const JxlCmsInterface& cms, ThreadPool* pool,
                          AuxOut* aux_out) {
  const CompressParams& cparams = enc_state->cparams;
  if (cparams.resampling > 1 &&
      cparams.original_butteraugli_distance <= 4.0 * cparams.resampling) {
    // For downsampled opsin image, the butteraugli based adaptive quantization
    // loop would only make the size bigger without improving the distance much,
    // so in this case we enable it only for very high butteraugli targets.
    return;
  }
  Quantizer& quantizer = enc_state->shared.quantizer;
  ImageI& raw_quant_field = enc_state->shared.raw_quant_field;
  ImageF& quant_field = enc_state->initial_quant_field;

  // TODO(veluca): this should really be rather handled on the
  // ButteraugliComparator side.
  struct TemporaryShrink {
    TemporaryShrink(ImageBundle& bundle, size_t xsize, size_t ysize)
        : bundle(bundle),
          orig_xsize(bundle.xsize()),
          orig_ysize(bundle.ysize()) {
      bundle.ShrinkTo(xsize, ysize);
    }
    TemporaryShrink(const TemporaryShrink&) = delete;
    TemporaryShrink(TemporaryShrink&&) = delete;

    ~TemporaryShrink() { bundle.ShrinkTo(orig_xsize, orig_ysize); }

    ImageBundle& bundle;
    size_t orig_xsize;
    size_t orig_ysize;
  } t(const_cast<ImageBundle&>(linear),
      enc_state->shared.frame_header.frame_size.xsize,
      enc_state->shared.frame_header.frame_size.ysize);

  const float butteraugli_target = cparams.butteraugli_distance;
  const float original_butteraugli = cparams.original_butteraugli_distance;
  ButteraugliParams params;
  params.intensity_target = linear.metadata()->IntensityTarget();
  // Hack the default intensity target value to be 80.0, the intensity
  // target of sRGB images and a more reasonable viewing default than
  // JPEG XL file format's default.
  if (fabs(params.intensity_target - 255.0f) < 1e-3) {
    params.intensity_target = 80.0f;
  }
  JxlButteraugliComparator comparator(params, cms);
  JXL_CHECK(comparator.SetReferenceImage(linear));
  bool lower_is_better =
      (comparator.GoodQualityScore() < comparator.BadQualityScore());
  const float initial_quant_dc = InitialQuantDC(butteraugli_target);
  AdjustQuantField(enc_state->shared.ac_strategy, Rect(quant_field),
                   original_butteraugli, &quant_field);
  ImageF tile_distmap;
  ImageF initial_quant_field(quant_field.xsize(), quant_field.ysize());
  CopyImageTo(quant_field, &initial_quant_field);

  float initial_qf_min, initial_qf_max;
  ImageMinMax(initial_quant_field, &initial_qf_min, &initial_qf_max);
  float initial_qf_ratio = initial_qf_max / initial_qf_min;
  float qf_max_deviation_low = std::sqrt(250 / initial_qf_ratio);
  float asymmetry = 2;
  if (qf_max_deviation_low < asymmetry) asymmetry = qf_max_deviation_low;
  float qf_lower = initial_qf_min / (asymmetry * qf_max_deviation_low);
  float qf_higher = initial_qf_max * (qf_max_deviation_low / asymmetry);

  JXL_ASSERT(qf_higher / qf_lower < 253);

  constexpr int kOriginalComparisonRound = 1;
  int iters = kMaxButteraugliIters;
  if (cparams.speed_tier != SpeedTier::kTortoise) {
    iters = 2;
  }
  for (int i = 0; i < iters + 1; ++i) {
    if (JXL_DEBUG_ADAPTIVE_QUANTIZATION) {
      printf("\nQuantization field:\n");
      for (size_t y = 0; y < quant_field.ysize(); ++y) {
        for (size_t x = 0; x < quant_field.xsize(); ++x) {
          printf(" %.5f", quant_field.Row(y)[x]);
        }
        printf("\n");
      }
    }
    quantizer.SetQuantField(initial_quant_dc, quant_field, &raw_quant_field);
    ImageBundle dec_linear = RoundtripImage(opsin, enc_state, cms, pool);
    float score;
    ImageF diffmap;
    JXL_CHECK(comparator.CompareWith(dec_linear, &diffmap, &score));
    if (!lower_is_better) {
      score = -score;
      ScaleImage(-1.0f, &diffmap);
    }
    tile_distmap = TileDistMap(diffmap, 8 * cparams.resampling, 0,
                               enc_state->shared.ac_strategy);
    if (JXL_DEBUG_ADAPTIVE_QUANTIZATION && WantDebugOutput(cparams)) {
      DumpImage(cparams, ("dec" + ToString(i)).c_str(), *dec_linear.color());
      DumpHeatmaps(cparams, aux_out, butteraugli_target, quant_field,
                   tile_distmap, diffmap);
    }
    if (aux_out != nullptr) ++aux_out->num_butteraugli_iters;
    if (JXL_DEBUG_ADAPTIVE_QUANTIZATION) {
      float minval, maxval;
      ImageMinMax(quant_field, &minval, &maxval);
      printf("\nButteraugli iter: %d/%d\n", i, kMaxButteraugliIters);
      printf("Butteraugli distance: %f  (target = %f)\n", score,
             original_butteraugli);
      printf("quant range: %f ... %f  DC quant: %f\n", minval, maxval,
             initial_quant_dc);
      if (FLAGS_dump_quant_state) {
        quantizer.DumpQuantizationMap(raw_quant_field);
      }
    }

    if (i == iters) break;

    double kPow[8] = {
        0.2, 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    };
    double kPowMod[8] = {
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    };
    if (i == kOriginalComparisonRound) {
      // Don't allow optimization to make the quant field a lot worse than
      // what the initial guess was. This allows the AC field to have enough
      // precision to reduce the oscillations due to the dc reconstruction.
      double kInitMul = 0.6;
      const double kOneMinusInitMul = 1.0 - kInitMul;
      for (size_t y = 0; y < quant_field.ysize(); ++y) {
        float* const JXL_RESTRICT row_q = quant_field.Row(y);
        const float* const JXL_RESTRICT row_init = initial_quant_field.Row(y);
        for (size_t x = 0; x < quant_field.xsize(); ++x) {
          double clamp = kOneMinusInitMul * row_q[x] + kInitMul * row_init[x];
          if (row_q[x] < clamp) {
            row_q[x] = clamp;
            if (row_q[x] > qf_higher) row_q[x] = qf_higher;
            if (row_q[x] < qf_lower) row_q[x] = qf_lower;
          }
        }
      }
    }

    double cur_pow = 0.0;
    if (i < 7) {
      cur_pow = kPow[i] + (original_butteraugli - 1.0) * kPowMod[i];
      if (cur_pow < 0) {
        cur_pow = 0;
      }
    }
    if (cur_pow == 0.0) {
      for (size_t y = 0; y < quant_field.ysize(); ++y) {
        const float* const JXL_RESTRICT row_dist = tile_distmap.Row(y);
        float* const JXL_RESTRICT row_q = quant_field.Row(y);
        for (size_t x = 0; x < quant_field.xsize(); ++x) {
          const float diff = row_dist[x] / original_butteraugli;
          if (diff > 1.0f) {
            float old = row_q[x];
            row_q[x] *= diff;
            int qf_old = old * quantizer.InvGlobalScale() + 0.5;
            int qf_new = row_q[x] * quantizer.InvGlobalScale() + 0.5;
            if (qf_old == qf_new) {
              row_q[x] = old + quantizer.Scale();
            }
          }
          if (row_q[x] > qf_higher) row_q[x] = qf_higher;
          if (row_q[x] < qf_lower) row_q[x] = qf_lower;
        }
      }
    } else {
      for (size_t y = 0; y < quant_field.ysize(); ++y) {
        const float* const JXL_RESTRICT row_dist = tile_distmap.Row(y);
        float* const JXL_RESTRICT row_q = quant_field.Row(y);
        for (size_t x = 0; x < quant_field.xsize(); ++x) {
          const float diff = row_dist[x] / original_butteraugli;
          if (diff <= 1.0f) {
            row_q[x] *= std::pow(diff, cur_pow);
          } else {
            float old = row_q[x];
            row_q[x] *= diff;
            int qf_old = old * quantizer.InvGlobalScale() + 0.5;
            int qf_new = row_q[x] * quantizer.InvGlobalScale() + 0.5;
            if (qf_old == qf_new) {
              row_q[x] = old + quantizer.Scale();
            }
          }
          if (row_q[x] > qf_higher) row_q[x] = qf_higher;
          if (row_q[x] < qf_lower) row_q[x] = qf_lower;
        }
      }
    }
  }
  quantizer.SetQuantField(initial_quant_dc, quant_field, &raw_quant_field);
}

void FindBestQuantizationMaxError(const Image3F& opsin,
                                  PassesEncoderState* enc_state,
                                  const JxlCmsInterface& cms, ThreadPool* pool,
                                  AuxOut* aux_out) {
  // TODO(szabadka): Make this work for non-opsin color spaces.
  const CompressParams& cparams = enc_state->cparams;
  Quantizer& quantizer = enc_state->shared.quantizer;
  ImageI& raw_quant_field = enc_state->shared.raw_quant_field;
  ImageF& quant_field = enc_state->initial_quant_field;

  // TODO(veluca): better choice of this value.
  const float initial_quant_dc =
      16 * std::sqrt(0.1f / cparams.butteraugli_distance);
  AdjustQuantField(enc_state->shared.ac_strategy, Rect(quant_field),
                   cparams.original_butteraugli_distance, &quant_field);

  const float inv_max_err[3] = {1.0f / enc_state->cparams.max_error[0],
                                1.0f / enc_state->cparams.max_error[1],
                                1.0f / enc_state->cparams.max_error[2]};

  for (int i = 0; i < kMaxButteraugliIters + 1; ++i) {
    quantizer.SetQuantField(initial_quant_dc, quant_field, &raw_quant_field);
    if (JXL_DEBUG_ADAPTIVE_QUANTIZATION && aux_out) {
      DumpXybImage(cparams, ("ops" + ToString(i)).c_str(), opsin);
    }
    ImageBundle decoded = RoundtripImage(opsin, enc_state, cms, pool);
    if (JXL_DEBUG_ADAPTIVE_QUANTIZATION && aux_out) {
      DumpXybImage(cparams, ("dec" + ToString(i)).c_str(), *decoded.color());
    }
    for (size_t by = 0; by < enc_state->shared.frame_dim.ysize_blocks; by++) {
      AcStrategyRow ac_strategy_row =
          enc_state->shared.ac_strategy.ConstRow(by);
      for (size_t bx = 0; bx < enc_state->shared.frame_dim.xsize_blocks; bx++) {
        AcStrategy acs = ac_strategy_row[bx];
        if (!acs.IsFirstBlock()) continue;
        float max_error = 0;
        for (size_t c = 0; c < 3; c++) {
          for (size_t y = by * kBlockDim;
               y < (by + acs.covered_blocks_y()) * kBlockDim; y++) {
            if (y >= decoded.ysize()) continue;
            const float* JXL_RESTRICT in_row = opsin.ConstPlaneRow(c, y);
            const float* JXL_RESTRICT dec_row =
                decoded.color()->ConstPlaneRow(c, y);
            for (size_t x = bx * kBlockDim;
                 x < (bx + acs.covered_blocks_x()) * kBlockDim; x++) {
              if (x >= decoded.xsize()) continue;
              max_error = std::max(
                  std::abs(in_row[x] - dec_row[x]) * inv_max_err[c], max_error);
            }
          }
        }
        // Target an error between max_error/2 and max_error.
        // If the error in the varblock is above the target, increase the qf to
        // compensate. If the error is below the target, decrease the qf.
        // However, to avoid an excessive increase of the qf, only do so if the
        // error is less than half the maximum allowed error.
        const float qf_mul = (max_error < 0.5f)   ? max_error * 2.0f
                             : (max_error > 1.0f) ? max_error
                                                  : 1.0f;
        for (size_t qy = by; qy < by + acs.covered_blocks_y(); qy++) {
          float* JXL_RESTRICT quant_field_row = quant_field.Row(qy);
          for (size_t qx = bx; qx < bx + acs.covered_blocks_x(); qx++) {
            quant_field_row[qx] *= qf_mul;
          }
        }
      }
    }
  }
  quantizer.SetQuantField(initial_quant_dc, quant_field, &raw_quant_field);
}

}  // namespace

void AdjustQuantField(const AcStrategyImage& ac_strategy, const Rect& rect,
                      float butteraugli_target, ImageF* quant_field) {
  // Replace the whole quant_field in non-8x8 blocks with the maximum of each
  // 8x8 block.
  size_t stride = quant_field->PixelsPerRow();

  // At low distances it is great to use max, but mean works better
  // at high distances. We interpolate between them for a distance
  // range.
  float mean_max_mixer = 1.0f;
  {
    static const float kLimit = 1.54138f;
    static const float kMul = 0.56391f;
    static const float kMin = 0.0f;
    if (butteraugli_target > kLimit) {
      mean_max_mixer -= (butteraugli_target - kLimit) * kMul;
      if (mean_max_mixer < kMin) {
        mean_max_mixer = kMin;
      }
    }
  }
  for (size_t y = 0; y < rect.ysize(); ++y) {
    AcStrategyRow ac_strategy_row = ac_strategy.ConstRow(rect, y);
    float* JXL_RESTRICT quant_row = rect.Row(quant_field, y);
    for (size_t x = 0; x < rect.xsize(); ++x) {
      AcStrategy acs = ac_strategy_row[x];
      if (!acs.IsFirstBlock()) continue;
      JXL_ASSERT(x + acs.covered_blocks_x() <= quant_field->xsize());
      JXL_ASSERT(y + acs.covered_blocks_y() <= quant_field->ysize());
      float max = quant_row[x];
      float mean = 0.0;
      for (size_t iy = 0; iy < acs.covered_blocks_y(); iy++) {
        for (size_t ix = 0; ix < acs.covered_blocks_x(); ix++) {
          mean += quant_row[x + ix + iy * stride];
          max = std::max(quant_row[x + ix + iy * stride], max);
        }
      }
      mean /= acs.covered_blocks_y() * acs.covered_blocks_x();
      if (acs.covered_blocks_y() * acs.covered_blocks_x() >= 4) {
        max *= mean_max_mixer;
        max += (1.0f - mean_max_mixer) * mean;
      }
      for (size_t iy = 0; iy < acs.covered_blocks_y(); iy++) {
        for (size_t ix = 0; ix < acs.covered_blocks_x(); ix++) {
          quant_row[x + ix + iy * stride] = max;
        }
      }
    }
  }
}

float InitialQuantDC(float butteraugli_target) {
  const float kDcMul = 0.3;  // Butteraugli target where non-linearity kicks in.
  const float butteraugli_target_dc = std::max<float>(
      0.5f * butteraugli_target,
      std::min<float>(butteraugli_target,
                      kDcMul * std::pow((1.0f / kDcMul) * butteraugli_target,
                                        kDcQuantPow)));
  // We want the maximum DC value to be at most 2**15 * kInvDCQuant / quant_dc.
  // The maximum DC value might not be in the kXybRange because of inverse
  // gaborish, so we add some slack to the maximum theoretical quant obtained
  // this way (64).
  return std::min(kDcQuant / butteraugli_target_dc, 50.f);
}

ImageF InitialQuantField(const float butteraugli_target, const Image3F& opsin,
                         const FrameDimensions& frame_dim, ThreadPool* pool,
                         float rescale, ImageF* mask) {
  const float quant_ac = kAcQuant / butteraugli_target;
  return HWY_DYNAMIC_DISPATCH(AdaptiveQuantizationMap)(
      butteraugli_target, opsin, frame_dim, quant_ac * rescale, pool, mask);
}

void FindBestQuantizer(const ImageBundle* linear, const Image3F& opsin,
                       PassesEncoderState* enc_state,
                       const JxlCmsInterface& cms, ThreadPool* pool,
                       AuxOut* aux_out, double rescale) {
  const CompressParams& cparams = enc_state->cparams;
  if (cparams.max_error_mode) {
    FindBestQuantizationMaxError(opsin, enc_state, cms, pool, aux_out);
  } else if (cparams.speed_tier <= SpeedTier::kKitten) {
    // Normal encoding to a butteraugli score.
    FindBestQuantization(*linear, opsin, enc_state, cms, pool, aux_out);
  }
}

}  // namespace jxl
#endif  // HWY_ONCE
