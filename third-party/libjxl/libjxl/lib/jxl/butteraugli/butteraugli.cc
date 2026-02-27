// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// Author: Jyrki Alakuijala (jyrki.alakuijala@gmail.com)
//
// The physical architecture of butteraugli is based on the following naming
// convention:
//   * Opsin - dynamics of the photosensitive chemicals in the retina
//             with their immediate electrical processing
//   * Xyb - hybrid opponent/trichromatic color space
//     x is roughly red-subtract-green.
//     y is yellow.
//     b is blue.
//     Xyb values are computed from Opsin mixing, not directly from rgb.
//   * Mask - for visual masking
//   * Hf - color modeling for spatially high-frequency features
//   * Lf - color modeling for spatially low-frequency features
//   * Diffmap - to cluster and build an image of error between the images
//   * Blur - to hold the smoothing code

#include "lib/jxl/butteraugli/butteraugli.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <new>
#include <vector>

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/butteraugli/butteraugli.cc"
#include <hwy/foreach_target.h>

#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/convolve.h"
#include "lib/jxl/fast_math-inl.h"
#include "lib/jxl/gauss_blur.h"
#include "lib/jxl/image_ops.h"

#ifndef JXL_BUTTERAUGLI_ONCE
#define JXL_BUTTERAUGLI_ONCE

namespace jxl {

std::vector<float> ComputeKernel(float sigma) {
  const float m = 2.25;  // Accuracy increases when m is increased.
  const double scaler = -1.0 / (2.0 * sigma * sigma);
  const int diff = std::max<int>(1, m * std::fabs(sigma));
  std::vector<float> kernel(2 * diff + 1);
  for (int i = -diff; i <= diff; ++i) {
    kernel[i + diff] = std::exp(scaler * i * i);
  }
  return kernel;
}

void ConvolveBorderColumn(const ImageF& in, const std::vector<float>& kernel,
                          const size_t x, float* BUTTERAUGLI_RESTRICT row_out) {
  const size_t offset = kernel.size() / 2;
  int minx = x < offset ? 0 : x - offset;
  int maxx = std::min<int>(in.xsize() - 1, x + offset);
  float weight = 0.0f;
  for (int j = minx; j <= maxx; ++j) {
    weight += kernel[j - x + offset];
  }
  float scale = 1.0f / weight;
  for (size_t y = 0; y < in.ysize(); ++y) {
    const float* BUTTERAUGLI_RESTRICT row_in = in.Row(y);
    float sum = 0.0f;
    for (int j = minx; j <= maxx; ++j) {
      sum += row_in[j] * kernel[j - x + offset];
    }
    row_out[y] = sum * scale;
  }
}

// Computes a horizontal convolution and transposes the result.
void ConvolutionWithTranspose(const ImageF& in,
                              const std::vector<float>& kernel,
                              ImageF* BUTTERAUGLI_RESTRICT out) {
  JXL_CHECK(out->xsize() == in.ysize());
  JXL_CHECK(out->ysize() == in.xsize());
  const size_t len = kernel.size();
  const size_t offset = len / 2;
  float weight_no_border = 0.0f;
  for (size_t j = 0; j < len; ++j) {
    weight_no_border += kernel[j];
  }
  const float scale_no_border = 1.0f / weight_no_border;
  const size_t border1 = std::min(in.xsize(), offset);
  const size_t border2 = in.xsize() > offset ? in.xsize() - offset : 0;
  std::vector<float> scaled_kernel(len / 2 + 1);
  for (size_t i = 0; i <= len / 2; ++i) {
    scaled_kernel[i] = kernel[i] * scale_no_border;
  }

  // middle
  switch (len) {
    case 7: {
      const float sk0 = scaled_kernel[0];
      const float sk1 = scaled_kernel[1];
      const float sk2 = scaled_kernel[2];
      const float sk3 = scaled_kernel[3];
      for (size_t y = 0; y < in.ysize(); ++y) {
        const float* BUTTERAUGLI_RESTRICT row_in = in.Row(y) + border1 - offset;
        for (size_t x = border1; x < border2; ++x, ++row_in) {
          const float sum0 = (row_in[0] + row_in[6]) * sk0;
          const float sum1 = (row_in[1] + row_in[5]) * sk1;
          const float sum2 = (row_in[2] + row_in[4]) * sk2;
          const float sum = (row_in[3]) * sk3 + sum0 + sum1 + sum2;
          float* BUTTERAUGLI_RESTRICT row_out = out->Row(x);
          row_out[y] = sum;
        }
      }
    } break;
    case 13: {
      for (size_t y = 0; y < in.ysize(); ++y) {
        const float* BUTTERAUGLI_RESTRICT row_in = in.Row(y) + border1 - offset;
        for (size_t x = border1; x < border2; ++x, ++row_in) {
          float sum0 = (row_in[0] + row_in[12]) * scaled_kernel[0];
          float sum1 = (row_in[1] + row_in[11]) * scaled_kernel[1];
          float sum2 = (row_in[2] + row_in[10]) * scaled_kernel[2];
          float sum3 = (row_in[3] + row_in[9]) * scaled_kernel[3];
          sum0 += (row_in[4] + row_in[8]) * scaled_kernel[4];
          sum1 += (row_in[5] + row_in[7]) * scaled_kernel[5];
          const float sum = (row_in[6]) * scaled_kernel[6];
          float* BUTTERAUGLI_RESTRICT row_out = out->Row(x);
          row_out[y] = sum + sum0 + sum1 + sum2 + sum3;
        }
      }
      break;
    }
    case 15: {
      for (size_t y = 0; y < in.ysize(); ++y) {
        const float* BUTTERAUGLI_RESTRICT row_in = in.Row(y) + border1 - offset;
        for (size_t x = border1; x < border2; ++x, ++row_in) {
          float sum0 = (row_in[0] + row_in[14]) * scaled_kernel[0];
          float sum1 = (row_in[1] + row_in[13]) * scaled_kernel[1];
          float sum2 = (row_in[2] + row_in[12]) * scaled_kernel[2];
          float sum3 = (row_in[3] + row_in[11]) * scaled_kernel[3];
          sum0 += (row_in[4] + row_in[10]) * scaled_kernel[4];
          sum1 += (row_in[5] + row_in[9]) * scaled_kernel[5];
          sum2 += (row_in[6] + row_in[8]) * scaled_kernel[6];
          const float sum = (row_in[7]) * scaled_kernel[7];
          float* BUTTERAUGLI_RESTRICT row_out = out->Row(x);
          row_out[y] = sum + sum0 + sum1 + sum2 + sum3;
        }
      }
      break;
    }
    case 33: {
      for (size_t y = 0; y < in.ysize(); ++y) {
        const float* BUTTERAUGLI_RESTRICT row_in = in.Row(y) + border1 - offset;
        for (size_t x = border1; x < border2; ++x, ++row_in) {
          float sum0 = (row_in[0] + row_in[32]) * scaled_kernel[0];
          float sum1 = (row_in[1] + row_in[31]) * scaled_kernel[1];
          float sum2 = (row_in[2] + row_in[30]) * scaled_kernel[2];
          float sum3 = (row_in[3] + row_in[29]) * scaled_kernel[3];
          sum0 += (row_in[4] + row_in[28]) * scaled_kernel[4];
          sum1 += (row_in[5] + row_in[27]) * scaled_kernel[5];
          sum2 += (row_in[6] + row_in[26]) * scaled_kernel[6];
          sum3 += (row_in[7] + row_in[25]) * scaled_kernel[7];
          sum0 += (row_in[8] + row_in[24]) * scaled_kernel[8];
          sum1 += (row_in[9] + row_in[23]) * scaled_kernel[9];
          sum2 += (row_in[10] + row_in[22]) * scaled_kernel[10];
          sum3 += (row_in[11] + row_in[21]) * scaled_kernel[11];
          sum0 += (row_in[12] + row_in[20]) * scaled_kernel[12];
          sum1 += (row_in[13] + row_in[19]) * scaled_kernel[13];
          sum2 += (row_in[14] + row_in[18]) * scaled_kernel[14];
          sum3 += (row_in[15] + row_in[17]) * scaled_kernel[15];
          const float sum = (row_in[16]) * scaled_kernel[16];
          float* BUTTERAUGLI_RESTRICT row_out = out->Row(x);
          row_out[y] = sum + sum0 + sum1 + sum2 + sum3;
        }
      }
      break;
    }
    default:
      JXL_UNREACHABLE("Kernel size %" PRIuS " not implemented", len);
  }
  // left border
  for (size_t x = 0; x < border1; ++x) {
    ConvolveBorderColumn(in, kernel, x, out->Row(x));
  }

  // right border
  for (size_t x = border2; x < in.xsize(); ++x) {
    ConvolveBorderColumn(in, kernel, x, out->Row(x));
  }
}

// A blur somewhat similar to a 2D Gaussian blur.
// See: https://en.wikipedia.org/wiki/Gaussian_blur
//
// This is a bottleneck because the sigma can be quite large (>7). We can use
// gauss_blur.cc (runtime independent of sigma, closer to a 4*sigma truncated
// Gaussian and our 2.25 in ComputeKernel), but its boundary conditions are
// zero-valued. This leads to noticeable differences at the edges of diffmaps.
// We retain a special case for 5x5 kernels (even faster than gauss_blur),
// optionally use gauss_blur followed by fixup of the borders for large images,
// or fall back to the previous truncated FIR followed by a transpose.
void Blur(const ImageF& in, float sigma, const ButteraugliParams& params,
          BlurTemp* temp, ImageF* out) {
  std::vector<float> kernel = ComputeKernel(sigma);
  // Separable5 does an in-place convolution, so this fast path is not safe if
  // in aliases out.
  if (kernel.size() == 5 && &in != out) {
    float sum_weights = 0.0f;
    for (const float w : kernel) {
      sum_weights += w;
    }
    const float scale = 1.0f / sum_weights;
    const float w0 = kernel[2] * scale;
    const float w1 = kernel[1] * scale;
    const float w2 = kernel[0] * scale;
    const WeightsSeparable5 weights = {
        {HWY_REP4(w0), HWY_REP4(w1), HWY_REP4(w2)},
        {HWY_REP4(w0), HWY_REP4(w1), HWY_REP4(w2)},
    };
    Separable5(in, Rect(in), weights, /*pool=*/nullptr, out);
    return;
  }

  ImageF* JXL_RESTRICT temp_t = temp->GetTransposed(in);
  ConvolutionWithTranspose(in, kernel, temp_t);
  ConvolutionWithTranspose(*temp_t, kernel, out);
}

// Allows PaddedMaltaUnit to call either function via overloading.
struct MaltaTagLF {};
struct MaltaTag {};

}  // namespace jxl

#endif  // JXL_BUTTERAUGLI_ONCE

#include <hwy/highway.h>
HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::Abs;
using hwy::HWY_NAMESPACE::Div;
using hwy::HWY_NAMESPACE::Gt;
using hwy::HWY_NAMESPACE::IfThenElse;
using hwy::HWY_NAMESPACE::IfThenElseZero;
using hwy::HWY_NAMESPACE::Lt;
using hwy::HWY_NAMESPACE::Max;
using hwy::HWY_NAMESPACE::Mul;
using hwy::HWY_NAMESPACE::MulAdd;
using hwy::HWY_NAMESPACE::MulSub;
using hwy::HWY_NAMESPACE::Neg;
using hwy::HWY_NAMESPACE::Sub;
using hwy::HWY_NAMESPACE::Vec;
using hwy::HWY_NAMESPACE::ZeroIfNegative;

template <class D, class V>
HWY_INLINE V MaximumClamp(D d, V v, double kMaxVal) {
  static const double kMul = 0.724216145665;
  const V mul = Set(d, kMul);
  const V maxval = Set(d, kMaxVal);
  // If greater than maxval or less than -maxval, replace with if_*.
  const V if_pos = MulAdd(Sub(v, maxval), mul, maxval);
  const V if_neg = MulSub(Add(v, maxval), mul, maxval);
  const V pos_or_v = IfThenElse(Ge(v, maxval), if_pos, v);
  return IfThenElse(Lt(v, Neg(maxval)), if_neg, pos_or_v);
}

// Make area around zero less important (remove it).
template <class D, class V>
HWY_INLINE V RemoveRangeAroundZero(const D d, const double kw, const V x) {
  const auto w = Set(d, kw);
  return IfThenElse(Gt(x, w), Sub(x, w),
                    IfThenElseZero(Lt(x, Neg(w)), Add(x, w)));
}

// Make area around zero more important (2x it until the limit).
template <class D, class V>
HWY_INLINE V AmplifyRangeAroundZero(const D d, const double kw, const V x) {
  const auto w = Set(d, kw);
  return IfThenElse(Gt(x, w), Add(x, w),
                    IfThenElse(Lt(x, Neg(w)), Sub(x, w), Add(x, x)));
}

// XybLowFreqToVals converts from low-frequency XYB space to the 'vals' space.
// Vals space can be converted to L2-norm space (Euclidean and normalized)
// through visual masking.
template <class D, class V>
HWY_INLINE void XybLowFreqToVals(const D d, const V& x, const V& y,
                                 const V& b_arg, V* HWY_RESTRICT valx,
                                 V* HWY_RESTRICT valy, V* HWY_RESTRICT valb) {
  static const double xmul_scalar = 33.832837186260;
  static const double ymul_scalar = 14.458268100570;
  static const double bmul_scalar = 49.87984651440;
  static const double y_to_b_mul_scalar = -0.362267051518;
  const V xmul = Set(d, xmul_scalar);
  const V ymul = Set(d, ymul_scalar);
  const V bmul = Set(d, bmul_scalar);
  const V y_to_b_mul = Set(d, y_to_b_mul_scalar);
  const V b = MulAdd(y_to_b_mul, y, b_arg);
  *valb = Mul(b, bmul);
  *valx = Mul(x, xmul);
  *valy = Mul(y, ymul);
}

void SuppressXByY(const ImageF& in_x, const ImageF& in_y, const double yw,
                  ImageF* HWY_RESTRICT out) {
  JXL_DASSERT(SameSize(in_x, in_y) && SameSize(in_x, *out));
  const size_t xsize = in_x.xsize();
  const size_t ysize = in_x.ysize();

  const HWY_FULL(float) d;
  static const double s = 0.653020556257;
  const auto sv = Set(d, s);
  const auto one_minus_s = Set(d, 1.0 - s);
  const auto ywv = Set(d, yw);

  for (size_t y = 0; y < ysize; ++y) {
    const float* HWY_RESTRICT row_x = in_x.ConstRow(y);
    const float* HWY_RESTRICT row_y = in_y.ConstRow(y);
    float* HWY_RESTRICT row_out = out->Row(y);

    for (size_t x = 0; x < xsize; x += Lanes(d)) {
      const auto vx = Load(d, row_x + x);
      const auto vy = Load(d, row_y + x);
      const auto scaler =
          MulAdd(Div(ywv, MulAdd(vy, vy, ywv)), one_minus_s, sv);
      Store(Mul(scaler, vx), d, row_out + x);
    }
  }
}

static void SeparateFrequencies(size_t xsize, size_t ysize,
                                const ButteraugliParams& params,
                                BlurTemp* blur_temp, const Image3F& xyb,
                                PsychoImage& ps) {
  const HWY_FULL(float) d;

  // Extract lf ...
  static const double kSigmaLf = 7.15593339443;
  static const double kSigmaHf = 3.22489901262;
  static const double kSigmaUhf = 1.56416327805;
  ps.mf = Image3F(xsize, ysize);
  ps.hf[0] = ImageF(xsize, ysize);
  ps.hf[1] = ImageF(xsize, ysize);
  ps.lf = Image3F(xyb.xsize(), xyb.ysize());
  ps.mf = Image3F(xyb.xsize(), xyb.ysize());
  for (int i = 0; i < 3; ++i) {
    Blur(xyb.Plane(i), kSigmaLf, params, blur_temp, &ps.lf.Plane(i));

    // ... and keep everything else in mf.
    for (size_t y = 0; y < ysize; ++y) {
      const float* BUTTERAUGLI_RESTRICT row_xyb = xyb.PlaneRow(i, y);
      const float* BUTTERAUGLI_RESTRICT row_lf = ps.lf.ConstPlaneRow(i, y);
      float* BUTTERAUGLI_RESTRICT row_mf = ps.mf.PlaneRow(i, y);
      for (size_t x = 0; x < xsize; x += Lanes(d)) {
        const auto mf = Sub(Load(d, row_xyb + x), Load(d, row_lf + x));
        Store(mf, d, row_mf + x);
      }
    }
    if (i == 2) {
      Blur(ps.mf.Plane(i), kSigmaHf, params, blur_temp, &ps.mf.Plane(i));
      break;
    }
    // Divide mf into mf and hf.
    for (size_t y = 0; y < ysize; ++y) {
      float* BUTTERAUGLI_RESTRICT row_mf = ps.mf.PlaneRow(i, y);
      float* BUTTERAUGLI_RESTRICT row_hf = ps.hf[i].Row(y);
      for (size_t x = 0; x < xsize; x += Lanes(d)) {
        Store(Load(d, row_mf + x), d, row_hf + x);
      }
    }
    Blur(ps.mf.Plane(i), kSigmaHf, params, blur_temp, &ps.mf.Plane(i));
    static const double kRemoveMfRange = 0.29;
    static const double kAddMfRange = 0.1;
    if (i == 0) {
      for (size_t y = 0; y < ysize; ++y) {
        float* BUTTERAUGLI_RESTRICT row_mf = ps.mf.PlaneRow(0, y);
        float* BUTTERAUGLI_RESTRICT row_hf = ps.hf[0].Row(y);
        for (size_t x = 0; x < xsize; x += Lanes(d)) {
          auto mf = Load(d, row_mf + x);
          auto hf = Sub(Load(d, row_hf + x), mf);
          mf = RemoveRangeAroundZero(d, kRemoveMfRange, mf);
          Store(mf, d, row_mf + x);
          Store(hf, d, row_hf + x);
        }
      }
    } else {
      for (size_t y = 0; y < ysize; ++y) {
        float* BUTTERAUGLI_RESTRICT row_mf = ps.mf.PlaneRow(1, y);
        float* BUTTERAUGLI_RESTRICT row_hf = ps.hf[1].Row(y);
        for (size_t x = 0; x < xsize; x += Lanes(d)) {
          auto mf = Load(d, row_mf + x);
          auto hf = Sub(Load(d, row_hf + x), mf);

          mf = AmplifyRangeAroundZero(d, kAddMfRange, mf);
          Store(mf, d, row_mf + x);
          Store(hf, d, row_hf + x);
        }
      }
    }
  }

  // Temporarily used as output of SuppressXByY
  ps.uhf[0] = ImageF(xsize, ysize);
  ps.uhf[1] = ImageF(xsize, ysize);

  // Suppress red-green by intensity change in the high freq channels.
  static const double suppress = 46.0;
  SuppressXByY(ps.hf[0], ps.hf[1], suppress, &ps.uhf[0]);
  // hf is the SuppressXByY output, uhf will be written below.
  ps.hf[0].Swap(ps.uhf[0]);

  for (int i = 0; i < 2; ++i) {
    // Divide hf into hf and uhf.
    for (size_t y = 0; y < ysize; ++y) {
      float* BUTTERAUGLI_RESTRICT row_uhf = ps.uhf[i].Row(y);
      float* BUTTERAUGLI_RESTRICT row_hf = ps.hf[i].Row(y);
      for (size_t x = 0; x < xsize; ++x) {
        row_uhf[x] = row_hf[x];
      }
    }
    Blur(ps.hf[i], kSigmaUhf, params, blur_temp, &ps.hf[i]);
    static const double kRemoveHfRange = 1.5;
    static const double kAddHfRange = 0.132;
    static const double kRemoveUhfRange = 0.04;
    static const double kMaxclampHf = 28.4691806922;
    static const double kMaxclampUhf = 5.19175294647;
    static double kMulYHf = 2.155;
    static double kMulYUhf = 2.69313763794;
    if (i == 0) {
      for (size_t y = 0; y < ysize; ++y) {
        float* BUTTERAUGLI_RESTRICT row_uhf = ps.uhf[0].Row(y);
        float* BUTTERAUGLI_RESTRICT row_hf = ps.hf[0].Row(y);
        for (size_t x = 0; x < xsize; x += Lanes(d)) {
          auto hf = Load(d, row_hf + x);
          auto uhf = Sub(Load(d, row_uhf + x), hf);
          hf = RemoveRangeAroundZero(d, kRemoveHfRange, hf);
          uhf = RemoveRangeAroundZero(d, kRemoveUhfRange, uhf);
          Store(hf, d, row_hf + x);
          Store(uhf, d, row_uhf + x);
        }
      }
    } else {
      for (size_t y = 0; y < ysize; ++y) {
        float* BUTTERAUGLI_RESTRICT row_uhf = ps.uhf[1].Row(y);
        float* BUTTERAUGLI_RESTRICT row_hf = ps.hf[1].Row(y);
        for (size_t x = 0; x < xsize; x += Lanes(d)) {
          auto hf = Load(d, row_hf + x);
          hf = MaximumClamp(d, hf, kMaxclampHf);

          auto uhf = Sub(Load(d, row_uhf + x), hf);
          uhf = MaximumClamp(d, uhf, kMaxclampUhf);
          uhf = Mul(uhf, Set(d, kMulYUhf));
          Store(uhf, d, row_uhf + x);

          hf = Mul(hf, Set(d, kMulYHf));
          hf = AmplifyRangeAroundZero(d, kAddHfRange, hf);
          Store(hf, d, row_hf + x);
        }
      }
    }
  }
  // Modify range around zero code only concerns the high frequency
  // planes and only the X and Y channels.
  // Convert low freq xyb to vals space so that we can do a simple squared sum
  // diff on the low frequencies later.
  for (size_t y = 0; y < ysize; ++y) {
    float* BUTTERAUGLI_RESTRICT row_x = ps.lf.PlaneRow(0, y);
    float* BUTTERAUGLI_RESTRICT row_y = ps.lf.PlaneRow(1, y);
    float* BUTTERAUGLI_RESTRICT row_b = ps.lf.PlaneRow(2, y);
    for (size_t x = 0; x < xsize; x += Lanes(d)) {
      auto valx = Undefined(d);
      auto valy = Undefined(d);
      auto valb = Undefined(d);
      XybLowFreqToVals(d, Load(d, row_x + x), Load(d, row_y + x),
                       Load(d, row_b + x), &valx, &valy, &valb);
      Store(valx, d, row_x + x);
      Store(valy, d, row_y + x);
      Store(valb, d, row_b + x);
    }
  }
}

namespace {
template <typename V>
BUTTERAUGLI_INLINE V Sum(V a, V b, V c, V d) {
  return Add(Add(a, b), Add(c, d));
}
template <typename V>
BUTTERAUGLI_INLINE V Sum(V a, V b, V c, V d, V e) {
  return Sum(a, b, c, Add(d, e));
}
template <typename V>
BUTTERAUGLI_INLINE V Sum(V a, V b, V c, V d, V e, V f, V g) {
  return Sum(a, b, c, Sum(d, e, f, g));
}
template <typename V>
BUTTERAUGLI_INLINE V Sum(V a, V b, V c, V d, V e, V f, V g, V h, V i) {
  return Add(Add(Sum(a, b, c, d), Sum(e, f, g, h)), i);
}
}  // namespace

template <class D>
Vec<D> MaltaUnit(MaltaTagLF /*tag*/, const D df,
                 const float* BUTTERAUGLI_RESTRICT d, const intptr_t xs) {
  const intptr_t xs3 = 3 * xs;

  const auto center = LoadU(df, d);

  // x grows, y constant
  const auto sum_yconst = Sum(LoadU(df, d - 4), LoadU(df, d - 2), center,
                              LoadU(df, d + 2), LoadU(df, d + 4));
  // Will return this, sum of all line kernels
  auto retval = Mul(sum_yconst, sum_yconst);
  {
    // y grows, x constant
    auto sum = Sum(LoadU(df, d - xs3 - xs), LoadU(df, d - xs - xs), center,
                   LoadU(df, d + xs + xs), LoadU(df, d + xs3 + xs));
    retval = MulAdd(sum, sum, retval);
  }
  {
    // both grow
    auto sum = Sum(LoadU(df, d - xs3 - 3), LoadU(df, d - xs - xs - 2), center,
                   LoadU(df, d + xs + xs + 2), LoadU(df, d + xs3 + 3));
    retval = MulAdd(sum, sum, retval);
  }
  {
    // y grows, x shrinks
    auto sum = Sum(LoadU(df, d - xs3 + 3), LoadU(df, d - xs - xs + 2), center,
                   LoadU(df, d + xs + xs - 2), LoadU(df, d + xs3 - 3));
    retval = MulAdd(sum, sum, retval);
  }
  {
    // y grows -4 to 4, x shrinks 1 -> -1
    auto sum =
        Sum(LoadU(df, d - xs3 - xs + 1), LoadU(df, d - xs - xs + 1), center,
            LoadU(df, d + xs + xs - 1), LoadU(df, d + xs3 + xs - 1));
    retval = MulAdd(sum, sum, retval);
  }
  {
    //  y grows -4 to 4, x grows -1 -> 1
    auto sum =
        Sum(LoadU(df, d - xs3 - xs - 1), LoadU(df, d - xs - xs - 1), center,
            LoadU(df, d + xs + xs + 1), LoadU(df, d + xs3 + xs + 1));
    retval = MulAdd(sum, sum, retval);
  }
  {
    // x grows -4 to 4, y grows -1 to 1
    auto sum = Sum(LoadU(df, d - 4 - xs), LoadU(df, d - 2 - xs), center,
                   LoadU(df, d + 2 + xs), LoadU(df, d + 4 + xs));
    retval = MulAdd(sum, sum, retval);
  }
  {
    // x grows -4 to 4, y shrinks 1 to -1
    auto sum = Sum(LoadU(df, d - 4 + xs), LoadU(df, d - 2 + xs), center,
                   LoadU(df, d + 2 - xs), LoadU(df, d + 4 - xs));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_________
       1__*______
       2___*_____
       3_________
       4____0____
       5_________
       6_____*___
       7______*__
       8_________ */
    auto sum = Sum(LoadU(df, d - xs3 - 2), LoadU(df, d - xs - xs - 1), center,
                   LoadU(df, d + xs + xs + 1), LoadU(df, d + xs3 + 2));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_________
       1______*__
       2_____*___
       3_________
       4____0____
       5_________
       6___*_____
       7__*______
       8_________ */
    auto sum = Sum(LoadU(df, d - xs3 + 2), LoadU(df, d - xs - xs + 1), center,
                   LoadU(df, d + xs + xs - 1), LoadU(df, d + xs3 - 2));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_________
       1_________
       2_*_______
       3__*______
       4____0____
       5______*__
       6_______*_
       7_________
       8_________ */
    auto sum = Sum(LoadU(df, d - xs - xs - 3), LoadU(df, d - xs - 2), center,
                   LoadU(df, d + xs + 2), LoadU(df, d + xs + xs + 3));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_________
       1_________
       2_______*_
       3______*__
       4____0____
       5__*______
       6_*_______
       7_________
       8_________ */
    auto sum = Sum(LoadU(df, d - xs - xs + 3), LoadU(df, d - xs + 2), center,
                   LoadU(df, d + xs - 2), LoadU(df, d + xs + xs - 3));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_________
       1_________
       2________*
       3______*__
       4____0____
       5__*______
       6*________
       7_________
       8_________ */

    auto sum = Sum(LoadU(df, d + xs + xs - 4), LoadU(df, d + xs - 2), center,
                   LoadU(df, d - xs + 2), LoadU(df, d - xs - xs + 4));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_________
       1_________
       2*________
       3__*______
       4____0____
       5______*__
       6________*
       7_________
       8_________ */
    auto sum = Sum(LoadU(df, d - xs - xs - 4), LoadU(df, d - xs - 2), center,
                   LoadU(df, d + xs + 2), LoadU(df, d + xs + xs + 4));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0__*______
       1_________
       2___*_____
       3_________
       4____0____
       5_________
       6_____*___
       7_________
       8______*__ */
    auto sum =
        Sum(LoadU(df, d - xs3 - xs - 2), LoadU(df, d - xs - xs - 1), center,
            LoadU(df, d + xs + xs + 1), LoadU(df, d + xs3 + xs + 2));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0______*__
       1_________
       2_____*___
       3_________
       4____0____
       5_________
       6___*_____
       7_________
       8__*______ */
    auto sum =
        Sum(LoadU(df, d - xs3 - xs + 2), LoadU(df, d - xs - xs + 1), center,
            LoadU(df, d + xs + xs - 1), LoadU(df, d + xs3 + xs - 2));
    retval = MulAdd(sum, sum, retval);
  }
  return retval;
}

template <class D>
Vec<D> MaltaUnit(MaltaTag /*tag*/, const D df,
                 const float* BUTTERAUGLI_RESTRICT d, const intptr_t xs) {
  const intptr_t xs3 = 3 * xs;

  const auto center = LoadU(df, d);

  // x grows, y constant
  const auto sum_yconst =
      Sum(LoadU(df, d - 4), LoadU(df, d - 3), LoadU(df, d - 2),
          LoadU(df, d - 1), center, LoadU(df, d + 1), LoadU(df, d + 2),
          LoadU(df, d + 3), LoadU(df, d + 4));
  // Will return this, sum of all line kernels
  auto retval = Mul(sum_yconst, sum_yconst);

  {
    // y grows, x constant
    auto sum = Sum(LoadU(df, d - xs3 - xs), LoadU(df, d - xs3),
                   LoadU(df, d - xs - xs), LoadU(df, d - xs), center,
                   LoadU(df, d + xs), LoadU(df, d + xs + xs),
                   LoadU(df, d + xs3), LoadU(df, d + xs3 + xs));
    retval = MulAdd(sum, sum, retval);
  }
  {
    // both grow
    auto sum = Sum(LoadU(df, d - xs3 - 3), LoadU(df, d - xs - xs - 2),
                   LoadU(df, d - xs - 1), center, LoadU(df, d + xs + 1),
                   LoadU(df, d + xs + xs + 2), LoadU(df, d + xs3 + 3));
    retval = MulAdd(sum, sum, retval);
  }
  {
    // y grows, x shrinks
    auto sum = Sum(LoadU(df, d - xs3 + 3), LoadU(df, d - xs - xs + 2),
                   LoadU(df, d - xs + 1), center, LoadU(df, d + xs - 1),
                   LoadU(df, d + xs + xs - 2), LoadU(df, d + xs3 - 3));
    retval = MulAdd(sum, sum, retval);
  }
  {
    // y grows -4 to 4, x shrinks 1 -> -1
    auto sum = Sum(LoadU(df, d - xs3 - xs + 1), LoadU(df, d - xs3 + 1),
                   LoadU(df, d - xs - xs + 1), LoadU(df, d - xs), center,
                   LoadU(df, d + xs), LoadU(df, d + xs + xs - 1),
                   LoadU(df, d + xs3 - 1), LoadU(df, d + xs3 + xs - 1));
    retval = MulAdd(sum, sum, retval);
  }
  {
    //  y grows -4 to 4, x grows -1 -> 1
    auto sum = Sum(LoadU(df, d - xs3 - xs - 1), LoadU(df, d - xs3 - 1),
                   LoadU(df, d - xs - xs - 1), LoadU(df, d - xs), center,
                   LoadU(df, d + xs), LoadU(df, d + xs + xs + 1),
                   LoadU(df, d + xs3 + 1), LoadU(df, d + xs3 + xs + 1));
    retval = MulAdd(sum, sum, retval);
  }
  {
    // x grows -4 to 4, y grows -1 to 1
    auto sum =
        Sum(LoadU(df, d - 4 - xs), LoadU(df, d - 3 - xs), LoadU(df, d - 2 - xs),
            LoadU(df, d - 1), center, LoadU(df, d + 1), LoadU(df, d + 2 + xs),
            LoadU(df, d + 3 + xs), LoadU(df, d + 4 + xs));
    retval = MulAdd(sum, sum, retval);
  }
  {
    // x grows -4 to 4, y shrinks 1 to -1
    auto sum =
        Sum(LoadU(df, d - 4 + xs), LoadU(df, d - 3 + xs), LoadU(df, d - 2 + xs),
            LoadU(df, d - 1), center, LoadU(df, d + 1), LoadU(df, d + 2 - xs),
            LoadU(df, d + 3 - xs), LoadU(df, d + 4 - xs));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_________
       1__*______
       2___*_____
       3___*_____
       4____0____
       5_____*___
       6_____*___
       7______*__
       8_________ */
    auto sum = Sum(LoadU(df, d - xs3 - 2), LoadU(df, d - xs - xs - 1),
                   LoadU(df, d - xs - 1), center, LoadU(df, d + xs + 1),
                   LoadU(df, d + xs + xs + 1), LoadU(df, d + xs3 + 2));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_________
       1______*__
       2_____*___
       3_____*___
       4____0____
       5___*_____
       6___*_____
       7__*______
       8_________ */
    auto sum = Sum(LoadU(df, d - xs3 + 2), LoadU(df, d - xs - xs + 1),
                   LoadU(df, d - xs + 1), center, LoadU(df, d + xs - 1),
                   LoadU(df, d + xs + xs - 1), LoadU(df, d + xs3 - 2));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_________
       1_________
       2_*_______
       3__**_____
       4____0____
       5_____**__
       6_______*_
       7_________
       8_________ */
    auto sum = Sum(LoadU(df, d - xs - xs - 3), LoadU(df, d - xs - 2),
                   LoadU(df, d - xs - 1), center, LoadU(df, d + xs + 1),
                   LoadU(df, d + xs + 2), LoadU(df, d + xs + xs + 3));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_________
       1_________
       2_______*_
       3_____**__
       4____0____
       5__**_____
       6_*_______
       7_________
       8_________ */
    auto sum = Sum(LoadU(df, d - xs - xs + 3), LoadU(df, d - xs + 2),
                   LoadU(df, d - xs + 1), center, LoadU(df, d + xs - 1),
                   LoadU(df, d + xs - 2), LoadU(df, d + xs + xs - 3));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_________
       1_________
       2_________
       3______***
       4___*0*___
       5***______
       6_________
       7_________
       8_________ */

    auto sum =
        Sum(LoadU(df, d + xs - 4), LoadU(df, d + xs - 3), LoadU(df, d + xs - 2),
            LoadU(df, d - 1), center, LoadU(df, d + 1), LoadU(df, d - xs + 2),
            LoadU(df, d - xs + 3), LoadU(df, d - xs + 4));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_________
       1_________
       2_________
       3***______
       4___*0*___
       5______***
       6_________
       7_________
       8_________ */
    auto sum =
        Sum(LoadU(df, d - xs - 4), LoadU(df, d - xs - 3), LoadU(df, d - xs - 2),
            LoadU(df, d - 1), center, LoadU(df, d + 1), LoadU(df, d + xs + 2),
            LoadU(df, d + xs + 3), LoadU(df, d + xs + 4));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0___*_____
       1___*_____
       2___*_____
       3____*____
       4____0____
       5____*____
       6_____*___
       7_____*___
       8_____*___ */
    auto sum = Sum(LoadU(df, d - xs3 - xs - 1), LoadU(df, d - xs3 - 1),
                   LoadU(df, d - xs - xs - 1), LoadU(df, d - xs), center,
                   LoadU(df, d + xs), LoadU(df, d + xs + xs + 1),
                   LoadU(df, d + xs3 + 1), LoadU(df, d + xs3 + xs + 1));
    retval = MulAdd(sum, sum, retval);
  }
  {
    /* 0_____*___
       1_____*___
       2____ *___
       3____*____
       4____0____
       5____*____
       6___*_____
       7___*_____
       8___*_____ */
    auto sum = Sum(LoadU(df, d - xs3 - xs + 1), LoadU(df, d - xs3 + 1),
                   LoadU(df, d - xs - xs + 1), LoadU(df, d - xs), center,
                   LoadU(df, d + xs), LoadU(df, d + xs + xs - 1),
                   LoadU(df, d + xs3 - 1), LoadU(df, d + xs3 + xs - 1));
    retval = MulAdd(sum, sum, retval);
  }
  return retval;
}

// Returns MaltaUnit. Avoids bounds-checks when x0 and y0 are known
// to be far enough from the image borders. "diffs" is a packed image.
template <class Tag>
static BUTTERAUGLI_INLINE float PaddedMaltaUnit(const ImageF& diffs,
                                                const size_t x0,
                                                const size_t y0) {
  const float* BUTTERAUGLI_RESTRICT d = diffs.ConstRow(y0) + x0;
  const HWY_CAPPED(float, 1) df;
  if ((x0 >= 4 && y0 >= 4 && x0 < (diffs.xsize() - 4) &&
       y0 < (diffs.ysize() - 4))) {
    return GetLane(MaltaUnit(Tag(), df, d, diffs.PixelsPerRow()));
  }

  float borderimage[12 * 9];  // round up to 4
  for (int dy = 0; dy < 9; ++dy) {
    int y = y0 + dy - 4;
    if (y < 0 || static_cast<size_t>(y) >= diffs.ysize()) {
      for (int dx = 0; dx < 12; ++dx) {
        borderimage[dy * 12 + dx] = 0.0f;
      }
      continue;
    }

    const float* row_diffs = diffs.ConstRow(y);
    for (int dx = 0; dx < 9; ++dx) {
      int x = x0 + dx - 4;
      if (x < 0 || static_cast<size_t>(x) >= diffs.xsize()) {
        borderimage[dy * 12 + dx] = 0.0f;
      } else {
        borderimage[dy * 12 + dx] = row_diffs[x];
      }
    }
    std::fill(borderimage + dy * 12 + 9, borderimage + dy * 12 + 12, 0.0f);
  }
  return GetLane(MaltaUnit(Tag(), df, &borderimage[4 * 12 + 4], 12));
}

template <class Tag>
static void MaltaDiffMapT(const Tag tag, const ImageF& lum0, const ImageF& lum1,
                          const double w_0gt1, const double w_0lt1,
                          const double norm1, const double len,
                          const double mulli, ImageF* HWY_RESTRICT diffs,
                          Image3F* HWY_RESTRICT block_diff_ac, size_t c) {
  JXL_DASSERT(SameSize(lum0, lum1) && SameSize(lum0, *diffs));
  const size_t xsize_ = lum0.xsize();
  const size_t ysize_ = lum0.ysize();

  const float kWeight0 = 0.5;
  const float kWeight1 = 0.33;

  const double w_pre0gt1 = mulli * std::sqrt(kWeight0 * w_0gt1) / (len * 2 + 1);
  const double w_pre0lt1 = mulli * std::sqrt(kWeight1 * w_0lt1) / (len * 2 + 1);
  const float norm2_0gt1 = w_pre0gt1 * norm1;
  const float norm2_0lt1 = w_pre0lt1 * norm1;

  for (size_t y = 0; y < ysize_; ++y) {
    const float* HWY_RESTRICT row0 = lum0.ConstRow(y);
    const float* HWY_RESTRICT row1 = lum1.ConstRow(y);
    float* HWY_RESTRICT row_diffs = diffs->Row(y);
    for (size_t x = 0; x < xsize_; ++x) {
      const float absval = 0.5f * (std::abs(row0[x]) + std::abs(row1[x]));
      const float diff = row0[x] - row1[x];
      const float scaler = norm2_0gt1 / (static_cast<float>(norm1) + absval);

      // Primary symmetric quadratic objective.
      row_diffs[x] = scaler * diff;

      const float scaler2 = norm2_0lt1 / (static_cast<float>(norm1) + absval);
      const double fabs0 = std::fabs(row0[x]);

      // Secondary half-open quadratic objectives.
      const double too_small = 0.55 * fabs0;
      const double too_big = 1.05 * fabs0;

      if (row0[x] < 0) {
        if (row1[x] > -too_small) {
          double impact = scaler2 * (row1[x] + too_small);
          row_diffs[x] -= impact;
        } else if (row1[x] < -too_big) {
          double impact = scaler2 * (-row1[x] - too_big);
          row_diffs[x] += impact;
        }
      } else {
        if (row1[x] < too_small) {
          double impact = scaler2 * (too_small - row1[x]);
          row_diffs[x] += impact;
        } else if (row1[x] > too_big) {
          double impact = scaler2 * (row1[x] - too_big);
          row_diffs[x] -= impact;
        }
      }
    }
  }

  size_t y0 = 0;
  // Top
  for (; y0 < 4; ++y0) {
    float* BUTTERAUGLI_RESTRICT row_diff = block_diff_ac->PlaneRow(c, y0);
    for (size_t x0 = 0; x0 < xsize_; ++x0) {
      row_diff[x0] += PaddedMaltaUnit<Tag>(*diffs, x0, y0);
    }
  }

  const HWY_FULL(float) df;
  const size_t aligned_x = std::max(size_t(4), Lanes(df));
  const intptr_t stride = diffs->PixelsPerRow();

  // Middle
  for (; y0 < ysize_ - 4; ++y0) {
    const float* BUTTERAUGLI_RESTRICT row_in = diffs->ConstRow(y0);
    float* BUTTERAUGLI_RESTRICT row_diff = block_diff_ac->PlaneRow(c, y0);
    size_t x0 = 0;
    for (; x0 < aligned_x; ++x0) {
      row_diff[x0] += PaddedMaltaUnit<Tag>(*diffs, x0, y0);
    }
    for (; x0 + Lanes(df) + 4 <= xsize_; x0 += Lanes(df)) {
      auto diff = Load(df, row_diff + x0);
      diff = Add(diff, MaltaUnit(Tag(), df, row_in + x0, stride));
      Store(diff, df, row_diff + x0);
    }

    for (; x0 < xsize_; ++x0) {
      row_diff[x0] += PaddedMaltaUnit<Tag>(*diffs, x0, y0);
    }
  }

  // Bottom
  for (; y0 < ysize_; ++y0) {
    float* BUTTERAUGLI_RESTRICT row_diff = block_diff_ac->PlaneRow(c, y0);
    for (size_t x0 = 0; x0 < xsize_; ++x0) {
      row_diff[x0] += PaddedMaltaUnit<Tag>(*diffs, x0, y0);
    }
  }
}

// Need non-template wrapper functions for HWY_EXPORT.
void MaltaDiffMap(const ImageF& lum0, const ImageF& lum1, const double w_0gt1,
                  const double w_0lt1, const double norm1, const double len,
                  const double mulli, ImageF* HWY_RESTRICT diffs,
                  Image3F* HWY_RESTRICT block_diff_ac, size_t c) {
  MaltaDiffMapT(MaltaTag(), lum0, lum1, w_0gt1, w_0lt1, norm1, len, mulli,
                diffs, block_diff_ac, c);
}

void MaltaDiffMapLF(const ImageF& lum0, const ImageF& lum1, const double w_0gt1,
                    const double w_0lt1, const double norm1, const double len,
                    const double mulli, ImageF* HWY_RESTRICT diffs,
                    Image3F* HWY_RESTRICT block_diff_ac, size_t c) {
  MaltaDiffMapT(MaltaTagLF(), lum0, lum1, w_0gt1, w_0lt1, norm1, len, mulli,
                diffs, block_diff_ac, c);
}

void DiffPrecompute(const ImageF& xyb, float mul, float bias_arg, ImageF* out) {
  const size_t xsize = xyb.xsize();
  const size_t ysize = xyb.ysize();
  const float bias = mul * bias_arg;
  const float sqrt_bias = sqrt(bias);
  for (size_t y = 0; y < ysize; ++y) {
    const float* BUTTERAUGLI_RESTRICT row_in = xyb.Row(y);
    float* BUTTERAUGLI_RESTRICT row_out = out->Row(y);
    for (size_t x = 0; x < xsize; ++x) {
      // kBias makes sqrt behave more linearly.
      row_out[x] = sqrt(mul * std::abs(row_in[x]) + bias) - sqrt_bias;
    }
  }
}

// std::log(80.0) / std::log(255.0);
constexpr float kIntensityTargetNormalizationHack = 0.79079917404f;
static const float kInternalGoodQualityThreshold =
    17.83f * kIntensityTargetNormalizationHack;
static const float kGlobalScale = 1.0 / kInternalGoodQualityThreshold;

void StoreMin3(const float v, float& min0, float& min1, float& min2) {
  if (v < min2) {
    if (v < min0) {
      min2 = min1;
      min1 = min0;
      min0 = v;
    } else if (v < min1) {
      min2 = min1;
      min1 = v;
    } else {
      min2 = v;
    }
  }
}

// Look for smooth areas near the area of degradation.
// If the areas area generally smooth, don't do masking.
void FuzzyErosion(const ImageF& from, ImageF* to) {
  const size_t xsize = from.xsize();
  const size_t ysize = from.ysize();
  static const int kStep = 3;
  for (size_t y = 0; y < ysize; ++y) {
    for (size_t x = 0; x < xsize; ++x) {
      float min0 = from.Row(y)[x];
      float min1 = 2 * min0;
      float min2 = min1;
      if (x >= kStep) {
        float v = from.Row(y)[x - kStep];
        StoreMin3(v, min0, min1, min2);
        if (y >= kStep) {
          float v = from.Row(y - kStep)[x - kStep];
          StoreMin3(v, min0, min1, min2);
        }
        if (y < ysize - kStep) {
          float v = from.Row(y + kStep)[x - kStep];
          StoreMin3(v, min0, min1, min2);
        }
      }
      if (x < xsize - kStep) {
        float v = from.Row(y)[x + kStep];
        StoreMin3(v, min0, min1, min2);
        if (y >= kStep) {
          float v = from.Row(y - kStep)[x + kStep];
          StoreMin3(v, min0, min1, min2);
        }
        if (y < ysize - kStep) {
          float v = from.Row(y + kStep)[x + kStep];
          StoreMin3(v, min0, min1, min2);
        }
      }
      if (y >= kStep) {
        float v = from.Row(y - kStep)[x];
        StoreMin3(v, min0, min1, min2);
      }
      if (y < ysize - kStep) {
        float v = from.Row(y + kStep)[x];
        StoreMin3(v, min0, min1, min2);
      }
      to->Row(y)[x] = (0.45f * min0 + 0.3f * min1 + 0.25f * min2);
    }
  }
}

// Compute values of local frequency and dc masking based on the activity
// in the two images. img_diff_ac may be null.
void Mask(const ImageF& mask0, const ImageF& mask1,
          const ButteraugliParams& params, BlurTemp* blur_temp,
          ImageF* BUTTERAUGLI_RESTRICT mask,
          ImageF* BUTTERAUGLI_RESTRICT diff_ac) {
  // Only X and Y components are involved in masking. B's influence
  // is considered less important in the high frequency area, and we
  // don't model masking from lower frequency signals.
  const size_t xsize = mask0.xsize();
  const size_t ysize = mask0.ysize();
  *mask = ImageF(xsize, ysize);
  static const float kMul = 6.19424080439;
  static const float kBias = 12.61050594197;
  static const float kRadius = 2.7;
  ImageF diff0(xsize, ysize);
  ImageF diff1(xsize, ysize);
  ImageF blurred0(xsize, ysize);
  ImageF blurred1(xsize, ysize);
  DiffPrecompute(mask0, kMul, kBias, &diff0);
  DiffPrecompute(mask1, kMul, kBias, &diff1);
  Blur(diff0, kRadius, params, blur_temp, &blurred0);
  FuzzyErosion(blurred0, &diff0);
  Blur(diff1, kRadius, params, blur_temp, &blurred1);
  FuzzyErosion(blurred1, &diff1);
  for (size_t y = 0; y < ysize; ++y) {
    for (size_t x = 0; x < xsize; ++x) {
      mask->Row(y)[x] = diff0.Row(y)[x];
      if (diff_ac != nullptr) {
        static const float kMaskToErrorMul = 10.0;
        float diff = blurred0.Row(y)[x] - blurred1.Row(y)[x];
        diff_ac->Row(y)[x] += kMaskToErrorMul * diff * diff;
      }
    }
  }
}

// `diff_ac` may be null.
void MaskPsychoImage(const PsychoImage& pi0, const PsychoImage& pi1,
                     const size_t xsize, const size_t ysize,
                     const ButteraugliParams& params, Image3F* temp,
                     BlurTemp* blur_temp, ImageF* BUTTERAUGLI_RESTRICT mask,
                     ImageF* BUTTERAUGLI_RESTRICT diff_ac) {
  ImageF mask0(xsize, ysize);
  ImageF mask1(xsize, ysize);
  static const float muls[3] = {
      2.5f,
      0.4f,
      0.4f,
  };
  // Silly and unoptimized approach here. TODO(jyrki): rework this.
  for (size_t y = 0; y < ysize; ++y) {
    const float* BUTTERAUGLI_RESTRICT row_y_hf0 = pi0.hf[1].Row(y);
    const float* BUTTERAUGLI_RESTRICT row_y_hf1 = pi1.hf[1].Row(y);
    const float* BUTTERAUGLI_RESTRICT row_y_uhf0 = pi0.uhf[1].Row(y);
    const float* BUTTERAUGLI_RESTRICT row_y_uhf1 = pi1.uhf[1].Row(y);
    const float* BUTTERAUGLI_RESTRICT row_x_hf0 = pi0.hf[0].Row(y);
    const float* BUTTERAUGLI_RESTRICT row_x_hf1 = pi1.hf[0].Row(y);
    const float* BUTTERAUGLI_RESTRICT row_x_uhf0 = pi0.uhf[0].Row(y);
    const float* BUTTERAUGLI_RESTRICT row_x_uhf1 = pi1.uhf[0].Row(y);
    float* BUTTERAUGLI_RESTRICT row0 = mask0.Row(y);
    float* BUTTERAUGLI_RESTRICT row1 = mask1.Row(y);
    for (size_t x = 0; x < xsize; ++x) {
      float xdiff0 = (row_x_uhf0[x] + row_x_hf0[x]) * muls[0];
      float xdiff1 = (row_x_uhf1[x] + row_x_hf1[x]) * muls[0];
      float ydiff0 = row_y_uhf0[x] * muls[1] + row_y_hf0[x] * muls[2];
      float ydiff1 = row_y_uhf1[x] * muls[1] + row_y_hf1[x] * muls[2];
      row0[x] = xdiff0 * xdiff0 + ydiff0 * ydiff0;
      row0[x] = sqrt(row0[x]);
      row1[x] = xdiff1 * xdiff1 + ydiff1 * ydiff1;
      row1[x] = sqrt(row1[x]);
    }
  }
  Mask(mask0, mask1, params, blur_temp, mask, diff_ac);
}

double MaskY(double delta) {
  static const double offset = 0.829591754942;
  static const double scaler = 0.451936922203;
  static const double mul = 2.5485944793;
  const double c = mul / ((scaler * delta) + offset);
  const double retval = kGlobalScale * (1.0 + c);
  return retval * retval;
}

double MaskDcY(double delta) {
  static const double offset = 0.20025578522;
  static const double scaler = 3.87449418804;
  static const double mul = 0.505054525019;
  const double c = mul / ((scaler * delta) + offset);
  const double retval = kGlobalScale * (1.0 + c);
  return retval * retval;
}

inline float MaskColor(const float color[3], const float mask) {
  return color[0] * mask + color[1] * mask + color[2] * mask;
}

// Diffmap := sqrt of sum{diff images by multiplied by X and Y/B masks}
void CombineChannelsToDiffmap(const ImageF& mask, const Image3F& block_diff_dc,
                              const Image3F& block_diff_ac, float xmul,
                              ImageF* result) {
  JXL_CHECK(SameSize(mask, *result));
  size_t xsize = mask.xsize();
  size_t ysize = mask.ysize();
  for (size_t y = 0; y < ysize; ++y) {
    float* BUTTERAUGLI_RESTRICT row_out = result->Row(y);
    for (size_t x = 0; x < xsize; ++x) {
      float val = mask.Row(y)[x];
      float maskval = MaskY(val);
      float dc_maskval = MaskDcY(val);
      float diff_dc[3];
      float diff_ac[3];
      for (int i = 0; i < 3; ++i) {
        diff_dc[i] = block_diff_dc.PlaneRow(i, y)[x];
        diff_ac[i] = block_diff_ac.PlaneRow(i, y)[x];
      }
      diff_ac[0] *= xmul;
      diff_dc[0] *= xmul;
      row_out[x] =
          sqrt(MaskColor(diff_dc, dc_maskval) + MaskColor(diff_ac, maskval));
    }
  }
}

// Adds weighted L2 difference between i0 and i1 to diffmap.
static void L2Diff(const ImageF& i0, const ImageF& i1, const float w,
                   Image3F* BUTTERAUGLI_RESTRICT diffmap, size_t c) {
  if (w == 0) return;

  const HWY_FULL(float) d;
  const auto weight = Set(d, w);

  for (size_t y = 0; y < i0.ysize(); ++y) {
    const float* BUTTERAUGLI_RESTRICT row0 = i0.ConstRow(y);
    const float* BUTTERAUGLI_RESTRICT row1 = i1.ConstRow(y);
    float* BUTTERAUGLI_RESTRICT row_diff = diffmap->PlaneRow(c, y);

    for (size_t x = 0; x < i0.xsize(); x += Lanes(d)) {
      const auto diff = Sub(Load(d, row0 + x), Load(d, row1 + x));
      const auto diff2 = Mul(diff, diff);
      const auto prev = Load(d, row_diff + x);
      Store(MulAdd(diff2, weight, prev), d, row_diff + x);
    }
  }
}

// Initializes diffmap to the weighted L2 difference between i0 and i1.
static void SetL2Diff(const ImageF& i0, const ImageF& i1, const float w,
                      Image3F* BUTTERAUGLI_RESTRICT diffmap, size_t c) {
  if (w == 0) return;

  const HWY_FULL(float) d;
  const auto weight = Set(d, w);

  for (size_t y = 0; y < i0.ysize(); ++y) {
    const float* BUTTERAUGLI_RESTRICT row0 = i0.ConstRow(y);
    const float* BUTTERAUGLI_RESTRICT row1 = i1.ConstRow(y);
    float* BUTTERAUGLI_RESTRICT row_diff = diffmap->PlaneRow(c, y);

    for (size_t x = 0; x < i0.xsize(); x += Lanes(d)) {
      const auto diff = Sub(Load(d, row0 + x), Load(d, row1 + x));
      const auto diff2 = Mul(diff, diff);
      Store(Mul(diff2, weight), d, row_diff + x);
    }
  }
}

// i0 is the original image.
// i1 is the deformed copy.
static void L2DiffAsymmetric(const ImageF& i0, const ImageF& i1, float w_0gt1,
                             float w_0lt1,
                             Image3F* BUTTERAUGLI_RESTRICT diffmap, size_t c) {
  if (w_0gt1 == 0 && w_0lt1 == 0) {
    return;
  }

  const HWY_FULL(float) d;
  const auto vw_0gt1 = Set(d, w_0gt1 * 0.8);
  const auto vw_0lt1 = Set(d, w_0lt1 * 0.8);

  for (size_t y = 0; y < i0.ysize(); ++y) {
    const float* BUTTERAUGLI_RESTRICT row0 = i0.Row(y);
    const float* BUTTERAUGLI_RESTRICT row1 = i1.Row(y);
    float* BUTTERAUGLI_RESTRICT row_diff = diffmap->PlaneRow(c, y);

    for (size_t x = 0; x < i0.xsize(); x += Lanes(d)) {
      const auto val0 = Load(d, row0 + x);
      const auto val1 = Load(d, row1 + x);

      // Primary symmetric quadratic objective.
      const auto diff = Sub(val0, val1);
      auto total = MulAdd(Mul(diff, diff), vw_0gt1, Load(d, row_diff + x));

      // Secondary half-open quadratic objectives.
      const auto fabs0 = Abs(val0);
      const auto too_small = Mul(Set(d, 0.4), fabs0);
      const auto too_big = fabs0;

      const auto if_neg = IfThenElse(
          Gt(val1, Neg(too_small)), Add(val1, too_small),
          IfThenElseZero(Lt(val1, Neg(too_big)), Sub(Neg(val1), too_big)));
      const auto if_pos =
          IfThenElse(Lt(val1, too_small), Sub(too_small, val1),
                     IfThenElseZero(Gt(val1, too_big), Sub(val1, too_big)));
      const auto v = IfThenElse(Lt(val0, Zero(d)), if_neg, if_pos);
      total = MulAdd(vw_0lt1, Mul(v, v), total);
      Store(total, d, row_diff + x);
    }
  }
}

// A simple HDR compatible gamma function.
template <class DF, class V>
V Gamma(const DF df, V v) {
  // ln(2) constant folded in because we want std::log but have FastLog2f.
  const auto kRetMul = Set(df, 19.245013259874995f * 0.693147180559945f);
  const auto kRetAdd = Set(df, -23.16046239805755);
  // This should happen rarely, but may lead to a NaN in log, which is
  // undesirable. Since negative photons don't exist we solve the NaNs by
  // clamping here.
  v = ZeroIfNegative(v);

  const auto biased = Add(v, Set(df, 9.9710635769299145));
  const auto log = FastLog2f(df, biased);
  // We could fold this into a custom Log2 polynomial, but there would be
  // relatively little gain.
  return MulAdd(kRetMul, log, kRetAdd);
}

template <bool Clamp, class DF, class V>
BUTTERAUGLI_INLINE void OpsinAbsorbance(const DF df, const V& in0, const V& in1,
                                        const V& in2, V* JXL_RESTRICT out0,
                                        V* JXL_RESTRICT out1,
                                        V* JXL_RESTRICT out2) {
  // https://en.wikipedia.org/wiki/Photopsin absorbance modeling.
  static const double mixi0 = 0.29956550340058319;
  static const double mixi1 = 0.63373087833825936;
  static const double mixi2 = 0.077705617820981968;
  static const double mixi3 = 1.7557483643287353;
  static const double mixi4 = 0.22158691104574774;
  static const double mixi5 = 0.69391388044116142;
  static const double mixi6 = 0.0987313588422;
  static const double mixi7 = 1.7557483643287353;
  static const double mixi8 = 0.02;
  static const double mixi9 = 0.02;
  static const double mixi10 = 0.20480129041026129;
  static const double mixi11 = 12.226454707163354;

  const V mix0 = Set(df, mixi0);
  const V mix1 = Set(df, mixi1);
  const V mix2 = Set(df, mixi2);
  const V mix3 = Set(df, mixi3);
  const V mix4 = Set(df, mixi4);
  const V mix5 = Set(df, mixi5);
  const V mix6 = Set(df, mixi6);
  const V mix7 = Set(df, mixi7);
  const V mix8 = Set(df, mixi8);
  const V mix9 = Set(df, mixi9);
  const V mix10 = Set(df, mixi10);
  const V mix11 = Set(df, mixi11);

  *out0 = MulAdd(mix0, in0, MulAdd(mix1, in1, MulAdd(mix2, in2, mix3)));
  *out1 = MulAdd(mix4, in0, MulAdd(mix5, in1, MulAdd(mix6, in2, mix7)));
  *out2 = MulAdd(mix8, in0, MulAdd(mix9, in1, MulAdd(mix10, in2, mix11)));

  if (Clamp) {
    *out0 = Max(*out0, mix3);
    *out1 = Max(*out1, mix7);
    *out2 = Max(*out2, mix11);
  }
}

// `blurred` is a temporary image used inside this function and not returned.
Image3F OpsinDynamicsImage(const Image3F& rgb, const ButteraugliParams& params,
                           Image3F* blurred, BlurTemp* blur_temp) {
  Image3F xyb(rgb.xsize(), rgb.ysize());
  const double kSigma = 1.2;
  Blur(rgb.Plane(0), kSigma, params, blur_temp, &blurred->Plane(0));
  Blur(rgb.Plane(1), kSigma, params, blur_temp, &blurred->Plane(1));
  Blur(rgb.Plane(2), kSigma, params, blur_temp, &blurred->Plane(2));
  const HWY_FULL(float) df;
  const auto intensity_target_multiplier = Set(df, params.intensity_target);
  for (size_t y = 0; y < rgb.ysize(); ++y) {
    const float* BUTTERAUGLI_RESTRICT row_r = rgb.ConstPlaneRow(0, y);
    const float* BUTTERAUGLI_RESTRICT row_g = rgb.ConstPlaneRow(1, y);
    const float* BUTTERAUGLI_RESTRICT row_b = rgb.ConstPlaneRow(2, y);
    const float* BUTTERAUGLI_RESTRICT row_blurred_r =
        blurred->ConstPlaneRow(0, y);
    const float* BUTTERAUGLI_RESTRICT row_blurred_g =
        blurred->ConstPlaneRow(1, y);
    const float* BUTTERAUGLI_RESTRICT row_blurred_b =
        blurred->ConstPlaneRow(2, y);
    float* BUTTERAUGLI_RESTRICT row_out_x = xyb.PlaneRow(0, y);
    float* BUTTERAUGLI_RESTRICT row_out_y = xyb.PlaneRow(1, y);
    float* BUTTERAUGLI_RESTRICT row_out_b = xyb.PlaneRow(2, y);
    const auto min = Set(df, 1e-4f);
    for (size_t x = 0; x < rgb.xsize(); x += Lanes(df)) {
      auto sensitivity0 = Undefined(df);
      auto sensitivity1 = Undefined(df);
      auto sensitivity2 = Undefined(df);
      {
        // Calculate sensitivity based on the smoothed image gamma derivative.
        auto pre_mixed0 = Undefined(df);
        auto pre_mixed1 = Undefined(df);
        auto pre_mixed2 = Undefined(df);
        OpsinAbsorbance<true>(
            df, Mul(Load(df, row_blurred_r + x), intensity_target_multiplier),
            Mul(Load(df, row_blurred_g + x), intensity_target_multiplier),
            Mul(Load(df, row_blurred_b + x), intensity_target_multiplier),
            &pre_mixed0, &pre_mixed1, &pre_mixed2);
        pre_mixed0 = Max(pre_mixed0, min);
        pre_mixed1 = Max(pre_mixed1, min);
        pre_mixed2 = Max(pre_mixed2, min);
        sensitivity0 = Div(Gamma(df, pre_mixed0), pre_mixed0);
        sensitivity1 = Div(Gamma(df, pre_mixed1), pre_mixed1);
        sensitivity2 = Div(Gamma(df, pre_mixed2), pre_mixed2);
        sensitivity0 = Max(sensitivity0, min);
        sensitivity1 = Max(sensitivity1, min);
        sensitivity2 = Max(sensitivity2, min);
      }
      auto cur_mixed0 = Undefined(df);
      auto cur_mixed1 = Undefined(df);
      auto cur_mixed2 = Undefined(df);
      OpsinAbsorbance<false>(
          df, Mul(Load(df, row_r + x), intensity_target_multiplier),
          Mul(Load(df, row_g + x), intensity_target_multiplier),
          Mul(Load(df, row_b + x), intensity_target_multiplier), &cur_mixed0,
          &cur_mixed1, &cur_mixed2);
      cur_mixed0 = Mul(cur_mixed0, sensitivity0);
      cur_mixed1 = Mul(cur_mixed1, sensitivity1);
      cur_mixed2 = Mul(cur_mixed2, sensitivity2);
      // This is a kludge. The negative values should be zeroed away before
      // blurring. Ideally there would be no negative values in the first place.
      const auto min01 = Set(df, 1.7557483643287353f);
      const auto min2 = Set(df, 12.226454707163354f);
      cur_mixed0 = Max(cur_mixed0, min01);
      cur_mixed1 = Max(cur_mixed1, min01);
      cur_mixed2 = Max(cur_mixed2, min2);

      Store(Sub(cur_mixed0, cur_mixed1), df, row_out_x + x);
      Store(Add(cur_mixed0, cur_mixed1), df, row_out_y + x);
      Store(cur_mixed2, df, row_out_b + x);
    }
  }
  return xyb;
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {

HWY_EXPORT(SeparateFrequencies);       // Local function.
HWY_EXPORT(MaskPsychoImage);           // Local function.
HWY_EXPORT(L2DiffAsymmetric);          // Local function.
HWY_EXPORT(L2Diff);                    // Local function.
HWY_EXPORT(SetL2Diff);                 // Local function.
HWY_EXPORT(CombineChannelsToDiffmap);  // Local function.
HWY_EXPORT(MaltaDiffMap);              // Local function.
HWY_EXPORT(MaltaDiffMapLF);            // Local function.
HWY_EXPORT(OpsinDynamicsImage);        // Local function.

#if BUTTERAUGLI_ENABLE_CHECKS

static inline bool IsNan(const float x) {
  uint32_t bits;
  memcpy(&bits, &x, sizeof(bits));
  const uint32_t bitmask_exp = 0x7F800000;
  return (bits & bitmask_exp) == bitmask_exp && (bits & 0x7FFFFF);
}

static inline bool IsNan(const double x) {
  uint64_t bits;
  memcpy(&bits, &x, sizeof(bits));
  return (0x7ff0000000000001ULL <= bits && bits <= 0x7fffffffffffffffULL) ||
         (0xfff0000000000001ULL <= bits && bits <= 0xffffffffffffffffULL);
}

static inline void CheckImage(const ImageF& image, const char* name) {
  for (size_t y = 0; y < image.ysize(); ++y) {
    const float* BUTTERAUGLI_RESTRICT row = image.Row(y);
    for (size_t x = 0; x < image.xsize(); ++x) {
      if (IsNan(row[x])) {
        printf("NAN: Image %s @ %" PRIuS ",%" PRIuS " (of %" PRIuS ",%" PRIuS
               ")\n",
               name, x, y, image.xsize(), image.ysize());
        exit(1);
      }
    }
  }
}

#define CHECK_NAN(x, str)                \
  do {                                   \
    if (IsNan(x)) {                      \
      printf("%d: %s\n", __LINE__, str); \
      abort();                           \
    }                                    \
  } while (0)

#define CHECK_IMAGE(image, name) CheckImage(image, name)

#else  // BUTTERAUGLI_ENABLE_CHECKS

#define CHECK_NAN(x, str)
#define CHECK_IMAGE(image, name)

#endif  // BUTTERAUGLI_ENABLE_CHECKS

// Calculate a 2x2 subsampled image for purposes of recursive butteraugli at
// multiresolution.
static Image3F SubSample2x(const Image3F& in) {
  size_t xs = (in.xsize() + 1) / 2;
  size_t ys = (in.ysize() + 1) / 2;
  Image3F retval(xs, ys);
  for (size_t c = 0; c < 3; ++c) {
    for (size_t y = 0; y < ys; ++y) {
      for (size_t x = 0; x < xs; ++x) {
        retval.PlaneRow(c, y)[x] = 0;
      }
    }
  }
  for (size_t c = 0; c < 3; ++c) {
    for (size_t y = 0; y < in.ysize(); ++y) {
      for (size_t x = 0; x < in.xsize(); ++x) {
        retval.PlaneRow(c, y / 2)[x / 2] += 0.25f * in.PlaneRow(c, y)[x];
      }
    }
    if ((in.xsize() & 1) != 0) {
      for (size_t y = 0; y < retval.ysize(); ++y) {
        size_t last_column = retval.xsize() - 1;
        retval.PlaneRow(c, y)[last_column] *= 2.0f;
      }
    }
    if ((in.ysize() & 1) != 0) {
      for (size_t x = 0; x < retval.xsize(); ++x) {
        size_t last_row = retval.ysize() - 1;
        retval.PlaneRow(c, last_row)[x] *= 2.0f;
      }
    }
  }
  return retval;
}

// Supersample src by 2x and add it to dest.
static void AddSupersampled2x(const ImageF& src, float w, ImageF& dest) {
  for (size_t y = 0; y < dest.ysize(); ++y) {
    for (size_t x = 0; x < dest.xsize(); ++x) {
      // There will be less errors from the more averaged images.
      // We take it into account to some extent using a scaler.
      static const double kHeuristicMixingValue = 0.3;
      dest.Row(y)[x] *= 1.0 - kHeuristicMixingValue * w;
      dest.Row(y)[x] += w * src.Row(y / 2)[x / 2];
    }
  }
}

Image3F* ButteraugliComparator::Temp() const {
  bool was_in_use = temp_in_use_.test_and_set(std::memory_order_acq_rel);
  JXL_ASSERT(!was_in_use);
  (void)was_in_use;
  return &temp_;
}

void ButteraugliComparator::ReleaseTemp() const { temp_in_use_.clear(); }

ButteraugliComparator::ButteraugliComparator(const Image3F& rgb0,
                                             const ButteraugliParams& params)
    : xsize_(rgb0.xsize()),
      ysize_(rgb0.ysize()),
      params_(params),
      temp_(xsize_, ysize_) {
  if (xsize_ < 8 || ysize_ < 8) {
    return;
  }

  Image3F xyb0 = HWY_DYNAMIC_DISPATCH(OpsinDynamicsImage)(rgb0, params, Temp(),
                                                          &blur_temp_);
  ReleaseTemp();
  HWY_DYNAMIC_DISPATCH(SeparateFrequencies)
  (xsize_, ysize_, params_, &blur_temp_, xyb0, pi0_);

  // Awful recursive construction of samples of different resolution.
  // This is an after-thought and possibly somewhat parallel in
  // functionality with the PsychoImage multi-resolution approach.
  sub_.reset(new ButteraugliComparator(SubSample2x(rgb0), params));
}

void ButteraugliComparator::Mask(ImageF* BUTTERAUGLI_RESTRICT mask) const {
  HWY_DYNAMIC_DISPATCH(MaskPsychoImage)
  (pi0_, pi0_, xsize_, ysize_, params_, Temp(), &blur_temp_, mask, nullptr);
  ReleaseTemp();
}

void ButteraugliComparator::Diffmap(const Image3F& rgb1, ImageF& result) const {
  if (xsize_ < 8 || ysize_ < 8) {
    ZeroFillImage(&result);
    return;
  }
  const Image3F xyb1 = HWY_DYNAMIC_DISPATCH(OpsinDynamicsImage)(
      rgb1, params_, Temp(), &blur_temp_);
  ReleaseTemp();
  DiffmapOpsinDynamicsImage(xyb1, result);
  if (sub_) {
    if (sub_->xsize_ < 8 || sub_->ysize_ < 8) {
      return;
    }
    const Image3F sub_xyb = HWY_DYNAMIC_DISPATCH(OpsinDynamicsImage)(
        SubSample2x(rgb1), params_, sub_->Temp(), &sub_->blur_temp_);
    sub_->ReleaseTemp();
    ImageF subresult;
    sub_->DiffmapOpsinDynamicsImage(sub_xyb, subresult);
    AddSupersampled2x(subresult, 0.5, result);
  }
}

void ButteraugliComparator::DiffmapOpsinDynamicsImage(const Image3F& xyb1,
                                                      ImageF& result) const {
  if (xsize_ < 8 || ysize_ < 8) {
    ZeroFillImage(&result);
    return;
  }
  PsychoImage pi1;
  HWY_DYNAMIC_DISPATCH(SeparateFrequencies)
  (xsize_, ysize_, params_, &blur_temp_, xyb1, pi1);
  result = ImageF(xsize_, ysize_);
  DiffmapPsychoImage(pi1, result);
}

namespace {

void MaltaDiffMap(const ImageF& lum0, const ImageF& lum1, const double w_0gt1,
                  const double w_0lt1, const double norm1,
                  ImageF* HWY_RESTRICT diffs,
                  Image3F* HWY_RESTRICT block_diff_ac, size_t c) {
  const double len = 3.75;
  static const double mulli = 0.39905817637;
  HWY_DYNAMIC_DISPATCH(MaltaDiffMap)
  (lum0, lum1, w_0gt1, w_0lt1, norm1, len, mulli, diffs, block_diff_ac, c);
}

void MaltaDiffMapLF(const ImageF& lum0, const ImageF& lum1, const double w_0gt1,
                    const double w_0lt1, const double norm1,
                    ImageF* HWY_RESTRICT diffs,
                    Image3F* HWY_RESTRICT block_diff_ac, size_t c) {
  const double len = 3.75;
  static const double mulli = 0.611612573796;
  HWY_DYNAMIC_DISPATCH(MaltaDiffMapLF)
  (lum0, lum1, w_0gt1, w_0lt1, norm1, len, mulli, diffs, block_diff_ac, c);
}

}  // namespace

void ButteraugliComparator::DiffmapPsychoImage(const PsychoImage& pi1,
                                               ImageF& diffmap) const {
  if (xsize_ < 8 || ysize_ < 8) {
    ZeroFillImage(&diffmap);
    return;
  }

  const float hf_asymmetry_ = params_.hf_asymmetry;
  const float xmul_ = params_.xmul;

  ImageF diffs(xsize_, ysize_);
  Image3F block_diff_ac(xsize_, ysize_);
  ZeroFillImage(&block_diff_ac);
  static const double wUhfMalta = 1.10039032555;
  static const double norm1Uhf = 71.7800275169;
  MaltaDiffMap(pi0_.uhf[1], pi1.uhf[1], wUhfMalta * hf_asymmetry_,
               wUhfMalta / hf_asymmetry_, norm1Uhf, &diffs, &block_diff_ac, 1);

  static const double wUhfMaltaX = 173.5;
  static const double norm1UhfX = 5.0;
  MaltaDiffMap(pi0_.uhf[0], pi1.uhf[0], wUhfMaltaX * hf_asymmetry_,
               wUhfMaltaX / hf_asymmetry_, norm1UhfX, &diffs, &block_diff_ac,
               0);

  static const double wHfMalta = 18.7237414387;
  static const double norm1Hf = 4498534.45232;
  MaltaDiffMapLF(pi0_.hf[1], pi1.hf[1], wHfMalta * std::sqrt(hf_asymmetry_),
                 wHfMalta / std::sqrt(hf_asymmetry_), norm1Hf, &diffs,
                 &block_diff_ac, 1);

  static const double wHfMaltaX = 6923.99476109;
  static const double norm1HfX = 8051.15833247;
  MaltaDiffMapLF(pi0_.hf[0], pi1.hf[0], wHfMaltaX * std::sqrt(hf_asymmetry_),
                 wHfMaltaX / std::sqrt(hf_asymmetry_), norm1HfX, &diffs,
                 &block_diff_ac, 0);

  static const double wMfMalta = 37.0819870399;
  static const double norm1Mf = 130262059.556;
  MaltaDiffMapLF(pi0_.mf.Plane(1), pi1.mf.Plane(1), wMfMalta, wMfMalta, norm1Mf,
                 &diffs, &block_diff_ac, 1);

  static const double wMfMaltaX = 8246.75321353;
  static const double norm1MfX = 1009002.70582;
  MaltaDiffMapLF(pi0_.mf.Plane(0), pi1.mf.Plane(0), wMfMaltaX, wMfMaltaX,
                 norm1MfX, &diffs, &block_diff_ac, 0);

  static const double wmul[9] = {
      400.0,         1.50815703118,  0,
      2150.0,        10.6195433239,  16.2176043152,
      29.2353797994, 0.844626970982, 0.703646627719,
  };
  Image3F block_diff_dc(xsize_, ysize_);
  for (size_t c = 0; c < 3; ++c) {
    if (c < 2) {  // No blue channel error accumulated at HF.
      HWY_DYNAMIC_DISPATCH(L2DiffAsymmetric)
      (pi0_.hf[c], pi1.hf[c], wmul[c] * hf_asymmetry_, wmul[c] / hf_asymmetry_,
       &block_diff_ac, c);
    }
    HWY_DYNAMIC_DISPATCH(L2Diff)
    (pi0_.mf.Plane(c), pi1.mf.Plane(c), wmul[3 + c], &block_diff_ac, c);
    HWY_DYNAMIC_DISPATCH(SetL2Diff)
    (pi0_.lf.Plane(c), pi1.lf.Plane(c), wmul[6 + c], &block_diff_dc, c);
  }

  ImageF mask;
  HWY_DYNAMIC_DISPATCH(MaskPsychoImage)
  (pi0_, pi1, xsize_, ysize_, params_, Temp(), &blur_temp_, &mask,
   &block_diff_ac.Plane(1));
  ReleaseTemp();

  HWY_DYNAMIC_DISPATCH(CombineChannelsToDiffmap)
  (mask, block_diff_dc, block_diff_ac, xmul_, &diffmap);
}

double ButteraugliScoreFromDiffmap(const ImageF& diffmap,
                                   const ButteraugliParams* params) {
  float retval = 0.0f;
  for (size_t y = 0; y < diffmap.ysize(); ++y) {
    const float* BUTTERAUGLI_RESTRICT row = diffmap.ConstRow(y);
    for (size_t x = 0; x < diffmap.xsize(); ++x) {
      retval = std::max(retval, row[x]);
    }
  }
  return retval;
}

bool ButteraugliDiffmap(const Image3F& rgb0, const Image3F& rgb1,
                        double hf_asymmetry, double xmul, ImageF& diffmap) {
  ButteraugliParams params;
  params.hf_asymmetry = hf_asymmetry;
  params.xmul = xmul;
  return ButteraugliDiffmap(rgb0, rgb1, params, diffmap);
}

bool ButteraugliDiffmap(const Image3F& rgb0, const Image3F& rgb1,
                        const ButteraugliParams& params, ImageF& diffmap) {
  const size_t xsize = rgb0.xsize();
  const size_t ysize = rgb0.ysize();
  if (xsize < 1 || ysize < 1) {
    return JXL_FAILURE("Zero-sized image");
  }
  if (!SameSize(rgb0, rgb1)) {
    return JXL_FAILURE("Size mismatch");
  }
  static const int kMax = 8;
  if (xsize < kMax || ysize < kMax) {
    // Butteraugli values for small (where xsize or ysize is smaller
    // than 8 pixels) images are non-sensical, but most likely it is
    // less disruptive to try to compute something than just give up.
    // Temporarily extend the borders of the image to fit 8 x 8 size.
    size_t xborder = xsize < kMax ? (kMax - xsize) / 2 : 0;
    size_t yborder = ysize < kMax ? (kMax - ysize) / 2 : 0;
    size_t xscaled = std::max<size_t>(kMax, xsize);
    size_t yscaled = std::max<size_t>(kMax, ysize);
    Image3F scaled0(xscaled, yscaled);
    Image3F scaled1(xscaled, yscaled);
    for (int i = 0; i < 3; ++i) {
      for (size_t y = 0; y < yscaled; ++y) {
        for (size_t x = 0; x < xscaled; ++x) {
          size_t x2 =
              std::min<size_t>(xsize - 1, x > xborder ? x - xborder : 0);
          size_t y2 =
              std::min<size_t>(ysize - 1, y > yborder ? y - yborder : 0);
          scaled0.PlaneRow(i, y)[x] = rgb0.PlaneRow(i, y2)[x2];
          scaled1.PlaneRow(i, y)[x] = rgb1.PlaneRow(i, y2)[x2];
        }
      }
    }
    ImageF diffmap_scaled;
    const bool ok =
        ButteraugliDiffmap(scaled0, scaled1, params, diffmap_scaled);
    diffmap = ImageF(xsize, ysize);
    for (size_t y = 0; y < ysize; ++y) {
      for (size_t x = 0; x < xsize; ++x) {
        diffmap.Row(y)[x] = diffmap_scaled.Row(y + yborder)[x + xborder];
      }
    }
    return ok;
  }
  ButteraugliComparator butteraugli(rgb0, params);
  butteraugli.Diffmap(rgb1, diffmap);
  return true;
}

bool ButteraugliInterface(const Image3F& rgb0, const Image3F& rgb1,
                          float hf_asymmetry, float xmul, ImageF& diffmap,
                          double& diffvalue) {
  ButteraugliParams params;
  params.hf_asymmetry = hf_asymmetry;
  params.xmul = xmul;
  return ButteraugliInterface(rgb0, rgb1, params, diffmap, diffvalue);
}

bool ButteraugliInterface(const Image3F& rgb0, const Image3F& rgb1,
                          const ButteraugliParams& params, ImageF& diffmap,
                          double& diffvalue) {
  if (!ButteraugliDiffmap(rgb0, rgb1, params, diffmap)) {
    return false;
  }
  diffvalue = ButteraugliScoreFromDiffmap(diffmap, &params);
  return true;
}

double ButteraugliFuzzyClass(double score) {
  static const double fuzzy_width_up = 4.8;
  static const double fuzzy_width_down = 4.8;
  static const double m0 = 2.0;
  static const double scaler = 0.7777;
  double val;
  if (score < 1.0) {
    // val in [scaler .. 2.0]
    val = m0 / (1.0 + exp((score - 1.0) * fuzzy_width_down));
    val -= 1.0;           // from [1 .. 2] to [0 .. 1]
    val *= 2.0 - scaler;  // from [0 .. 1] to [0 .. 2.0 - scaler]
    val += scaler;        // from [0 .. 2.0 - scaler] to [scaler .. 2.0]
  } else {
    // val in [0 .. scaler]
    val = m0 / (1.0 + exp((score - 1.0) * fuzzy_width_up));
    val *= scaler;
  }
  return val;
}

// #define PRINT_OUT_NORMALIZATION

double ButteraugliFuzzyInverse(double seek) {
  double pos = 0;
  // NOLINTNEXTLINE(clang-analyzer-security.FloatLoopCounter)
  for (double range = 1.0; range >= 1e-10; range *= 0.5) {
    double cur = ButteraugliFuzzyClass(pos);
    if (cur < seek) {
      pos -= range;
    } else {
      pos += range;
    }
  }
#ifdef PRINT_OUT_NORMALIZATION
  if (seek == 1.0) {
    fprintf(stderr, "Fuzzy inverse %g\n", pos);
  }
#endif
  return pos;
}

#ifdef PRINT_OUT_NORMALIZATION
static double print_out_normalization = ButteraugliFuzzyInverse(1.0);
#endif

namespace {

void ScoreToRgb(double score, double good_threshold, double bad_threshold,
                float rgb[3]) {
  double heatmap[12][3] = {
      {0, 0, 0},       {0, 0, 1},
      {0, 1, 1},       {0, 1, 0},  // Good level
      {1, 1, 0},       {1, 0, 0},  // Bad level
      {1, 0, 1},       {0.5, 0.5, 1.0},
      {1.0, 0.5, 0.5},  // Pastel colors for the very bad quality range.
      {1.0, 1.0, 0.5}, {1, 1, 1},
      {1, 1, 1},  // Last color repeated to have a solid range of white.
  };
  if (score < good_threshold) {
    score = (score / good_threshold) * 0.3;
  } else if (score < bad_threshold) {
    score = 0.3 +
            (score - good_threshold) / (bad_threshold - good_threshold) * 0.15;
  } else {
    score = 0.45 + (score - bad_threshold) / (bad_threshold * 12) * 0.5;
  }
  static const int kTableSize = sizeof(heatmap) / sizeof(heatmap[0]);
  score = std::min<double>(std::max<double>(score * (kTableSize - 1), 0.0),
                           kTableSize - 2);
  int ix = static_cast<int>(score);
  ix = std::min(std::max(0, ix), kTableSize - 2);  // Handle NaN
  double mix = score - ix;
  for (int i = 0; i < 3; ++i) {
    double v = mix * heatmap[ix + 1][i] + (1 - mix) * heatmap[ix][i];
    rgb[i] = pow(v, 0.5);
  }
}

}  // namespace

Image3F CreateHeatMapImage(const ImageF& distmap, double good_threshold,
                           double bad_threshold) {
  Image3F heatmap(distmap.xsize(), distmap.ysize());
  for (size_t y = 0; y < distmap.ysize(); ++y) {
    const float* BUTTERAUGLI_RESTRICT row_distmap = distmap.ConstRow(y);
    float* BUTTERAUGLI_RESTRICT row_h0 = heatmap.PlaneRow(0, y);
    float* BUTTERAUGLI_RESTRICT row_h1 = heatmap.PlaneRow(1, y);
    float* BUTTERAUGLI_RESTRICT row_h2 = heatmap.PlaneRow(2, y);
    for (size_t x = 0; x < distmap.xsize(); ++x) {
      const float d = row_distmap[x];
      float rgb[3];
      ScoreToRgb(d, good_threshold, bad_threshold, rgb);
      row_h0[x] = rgb[0];
      row_h1[x] = rgb[1];
      row_h2[x] = rgb[2];
    }
  }
  return heatmap;
}

}  // namespace jxl
#endif  // HWY_ONCE
