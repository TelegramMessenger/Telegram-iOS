// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Transfer functions for color encodings.

#if defined(LIB_JXL_TRANSFER_FUNCTIONS_INL_H_) == defined(HWY_TARGET_TOGGLE)
#ifdef LIB_JXL_TRANSFER_FUNCTIONS_INL_H_
#undef LIB_JXL_TRANSFER_FUNCTIONS_INL_H_
#else
#define LIB_JXL_TRANSFER_FUNCTIONS_INL_H_
#endif

#include <algorithm>
#include <cmath>
#include <hwy/highway.h>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/fast_math-inl.h"
#include "lib/jxl/rational_polynomial-inl.h"

HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::And;
using hwy::HWY_NAMESPACE::AndNot;
using hwy::HWY_NAMESPACE::Gt;
using hwy::HWY_NAMESPACE::IfThenElse;
using hwy::HWY_NAMESPACE::Lt;
using hwy::HWY_NAMESPACE::Or;
using hwy::HWY_NAMESPACE::Sqrt;
using hwy::HWY_NAMESPACE::TableLookupBytes;

// Definitions for BT.2100-2 transfer functions (used inside/outside SIMD):
// "display" is linear light (nits) normalized to [0, 1].
// "encoded" is a nonlinear encoding (e.g. PQ) in [0, 1].
// "scene" is a linear function of photon counts, normalized to [0, 1].

// Despite the stated ranges, we need unbounded transfer functions: see
// http://www.littlecms.com/CIC18_UnboundedCMM.pdf. Inputs can be negative or
// above 1 due to chromatic adaptation. To avoid severe round-trip errors caused
// by clamping, we mirror negative inputs via copysign (f(-x) = -f(x), see
// https://developer.apple.com/documentation/coregraphics/cgcolorspace/1644735-extendedsrgb)
// and extend the function domains above 1.

// Hybrid Log-Gamma.
class TF_HLG {
 public:
  // EOTF. e = encoded.
  JXL_INLINE double DisplayFromEncoded(const double e) const {
    return OOTF(InvOETF(e));
  }

  // Inverse EOTF. d = display.
  JXL_INLINE double EncodedFromDisplay(const double d) const {
    return OETF(InvOOTF(d));
  }

  // Maximum error 5e-7.
  template <class D, class V>
  JXL_INLINE V EncodedFromDisplay(D d, V x) const {
    const hwy::HWY_NAMESPACE::Rebind<uint32_t, D> du;
    const V kSign = BitCast(d, Set(du, 0x80000000u));
    const V original_sign = And(x, kSign);
    x = AndNot(kSign, x);  // abs
    const V below_div12 = Sqrt(Mul(Set(d, 3.0f), x));
    const V e =
        MulAdd(Set(d, kA * 0.693147181f),
               FastLog2f(d, MulAdd(Set(d, 12), x, Set(d, -kB))), Set(d, kC));
    const V magnitude = IfThenElse(Le(x, Set(d, kDiv12)), below_div12, e);
    return Or(AndNot(kSign, magnitude), original_sign);
  }

 private:
  // OETF (defines the HLG approach). s = scene, returns encoded.
  JXL_INLINE double OETF(double s) const {
    if (s == 0.0) return 0.0;
    const double original_sign = s;
    s = std::abs(s);

    if (s <= kDiv12) return copysignf(std::sqrt(3.0 * s), original_sign);

    const double e = kA * std::log(12 * s - kB) + kC;
    JXL_ASSERT(e > 0.0);
    return copysignf(e, original_sign);
  }

  // e = encoded, returns scene.
  JXL_INLINE double InvOETF(double e) const {
    if (e == 0.0) return 0.0;
    const double original_sign = e;
    e = std::abs(e);

    if (e <= 0.5) return copysignf(e * e * (1.0 / 3), original_sign);

    const double s = (std::exp((e - kC) * kRA) + kB) * kDiv12;
    JXL_ASSERT(s >= 0);
    return copysignf(s, original_sign);
  }

  // s = scene, returns display.
  JXL_INLINE double OOTF(const double s) const {
    // The actual (red channel) OOTF is RD = alpha * YS^(gamma-1) * RS, where
    // YS = 0.2627 * RS + 0.6780 * GS + 0.0593 * BS. Let alpha = 1 so we return
    // "display" (normalized [0, 1]) instead of nits. Our transfer function
    // interface does not allow a dependency on YS. Fortunately, the system
    // gamma at 334 nits is 1.0, so this reduces to RD = RS.
    return s;
  }

  // d = display, returns scene.
  JXL_INLINE double InvOOTF(const double d) const {
    return d;  // see OOTF().
  }

  static constexpr double kA = 0.17883277;
  static constexpr double kRA = 1.0 / kA;
  static constexpr double kB = 1 - 4 * kA;
  static constexpr double kC = 0.5599107295;
  static constexpr double kDiv12 = 1.0 / 12;
};

class TF_709 {
 public:
  JXL_INLINE double EncodedFromDisplay(const double d) const {
    if (d < kThresh) return kMulLow * d;
    return kMulHi * std::pow(d, kPowHi) + kSub;
  }

  // Maximum error 1e-6.
  template <class D, class V>
  JXL_INLINE V EncodedFromDisplay(D d, V x) const {
    auto low = Mul(Set(d, kMulLow), x);
    auto hi =
        MulAdd(Set(d, kMulHi), FastPowf(d, x, Set(d, kPowHi)), Set(d, kSub));
    return IfThenElse(Le(x, Set(d, kThresh)), low, hi);
  }

  template <class D, class V>
  JXL_INLINE V DisplayFromEncoded(D d, V x) const {
    auto low = Mul(Set(d, kInvMulLow), x);
    auto hi = FastPowf(d, MulAdd(x, Set(d, kInvMulHi), Set(d, kInvAdd)),
                       Set(d, kInvPowHi));
    return IfThenElse(Lt(x, Set(d, kInvThresh)), low, hi);
  }

 private:
  static constexpr double kThresh = 0.018;
  static constexpr double kMulLow = 4.5;
  static constexpr double kMulHi = 1.099;
  static constexpr double kPowHi = 0.45;
  static constexpr double kSub = -0.099;

  static constexpr double kInvThresh = 0.081;
  static constexpr double kInvMulLow = 1 / 4.5;
  static constexpr double kInvMulHi = 1 / 1.099;
  static constexpr double kInvPowHi = 1 / 0.45;
  static constexpr double kInvAdd = 0.099 * kInvMulHi;
};

// Perceptual Quantization
class TF_PQ {
 public:
  // EOTF (defines the PQ approach). e = encoded.
  JXL_INLINE double DisplayFromEncoded(double e) const {
    if (e == 0.0) return 0.0;
    const double original_sign = e;
    e = std::abs(e);

    const double xp = std::pow(e, 1.0 / kM2);
    const double num = std::max(xp - kC1, 0.0);
    const double den = kC2 - kC3 * xp;
    JXL_DASSERT(den != 0.0);
    const double d = std::pow(num / den, 1.0 / kM1);
    JXL_DASSERT(d >= 0.0);  // Equal for e ~= 1E-9
    return copysignf(d, original_sign);
  }

  // Maximum error 3e-6
  template <class D, class V>
  JXL_INLINE V DisplayFromEncoded(D d, V x) const {
    const hwy::HWY_NAMESPACE::Rebind<uint32_t, D> du;
    const V kSign = BitCast(d, Set(du, 0x80000000u));
    const V original_sign = And(x, kSign);
    x = AndNot(kSign, x);  // abs
    // 4-over-4-degree rational polynomial approximation on x+x*x. This improves
    // the maximum error by about 5x over a rational polynomial for x.
    auto xpxx = MulAdd(x, x, x);
    HWY_ALIGN constexpr float p[(4 + 1) * 4] = {
        HWY_REP4(2.62975656e-04f), HWY_REP4(-6.23553089e-03f),
        HWY_REP4(7.38602301e-01f), HWY_REP4(2.64553172e+00f),
        HWY_REP4(5.50034862e-01f),
    };
    HWY_ALIGN constexpr float q[(4 + 1) * 4] = {
        HWY_REP4(4.21350107e+02f), HWY_REP4(-4.28736818e+02f),
        HWY_REP4(1.74364667e+02f), HWY_REP4(-3.39078883e+01f),
        HWY_REP4(2.67718770e+00f),
    };
    auto magnitude = EvalRationalPolynomial(d, xpxx, p, q);
    return Or(AndNot(kSign, magnitude), original_sign);
  }

  // Inverse EOTF. d = display.
  JXL_INLINE double EncodedFromDisplay(double d) const {
    if (d == 0.0) return 0.0;
    const double original_sign = d;
    d = std::abs(d);

    const double xp = std::pow(d, kM1);
    const double num = kC1 + xp * kC2;
    const double den = 1.0 + xp * kC3;
    const double e = std::pow(num / den, kM2);
    JXL_DASSERT(e > 0.0);
    return copysignf(e, original_sign);
  }

  // Maximum error 7e-7.
  template <class D, class V>
  JXL_INLINE V EncodedFromDisplay(D d, V x) const {
    const hwy::HWY_NAMESPACE::Rebind<uint32_t, D> du;
    const V kSign = BitCast(d, Set(du, 0x80000000u));
    const V original_sign = And(x, kSign);
    x = AndNot(kSign, x);  // abs
    // 4-over-4-degree rational polynomial approximation on x**0.25, with two
    // different polynomials above and below 1e-4.
    auto xto025 = Sqrt(Sqrt(x));
    HWY_ALIGN constexpr float p[(4 + 1) * 4] = {
        HWY_REP4(1.351392e-02f), HWY_REP4(-1.095778e+00f),
        HWY_REP4(5.522776e+01f), HWY_REP4(1.492516e+02f),
        HWY_REP4(4.838434e+01f),
    };
    HWY_ALIGN constexpr float q[(4 + 1) * 4] = {
        HWY_REP4(1.012416e+00f), HWY_REP4(2.016708e+01f),
        HWY_REP4(9.263710e+01f), HWY_REP4(1.120607e+02f),
        HWY_REP4(2.590418e+01f),
    };

    HWY_ALIGN constexpr float plo[(4 + 1) * 4] = {
        HWY_REP4(9.863406e-06f),  HWY_REP4(3.881234e-01f),
        HWY_REP4(1.352821e+02f),  HWY_REP4(6.889862e+04f),
        HWY_REP4(-2.864824e+05f),
    };
    HWY_ALIGN constexpr float qlo[(4 + 1) * 4] = {
        HWY_REP4(3.371868e+01f),  HWY_REP4(1.477719e+03f),
        HWY_REP4(1.608477e+04f),  HWY_REP4(-4.389884e+04f),
        HWY_REP4(-2.072546e+05f),
    };

    auto magnitude = IfThenElse(Lt(x, Set(d, 1e-4f)),
                                EvalRationalPolynomial(d, xto025, plo, qlo),
                                EvalRationalPolynomial(d, xto025, p, q));
    return Or(AndNot(kSign, magnitude), original_sign);
  }

 private:
  static constexpr double kM1 = 2610.0 / 16384;
  static constexpr double kM2 = (2523.0 / 4096) * 128;
  static constexpr double kC1 = 3424.0 / 4096;
  static constexpr double kC2 = (2413.0 / 4096) * 32;
  static constexpr double kC3 = (2392.0 / 4096) * 32;
};

// sRGB
class TF_SRGB {
 public:
  template <typename V>
  JXL_INLINE V DisplayFromEncoded(V x) const {
    const HWY_FULL(float) d;
    const HWY_FULL(uint32_t) du;
    const V kSign = BitCast(d, Set(du, 0x80000000u));
    const V original_sign = And(x, kSign);
    x = AndNot(kSign, x);  // abs

    // TODO(janwas): range reduction
    // Computed via af_cheb_rational (k=100); replicated 4x.
    HWY_ALIGN constexpr float p[(4 + 1) * 4] = {
        2.200248328e-04f, 2.200248328e-04f, 2.200248328e-04f, 2.200248328e-04f,
        1.043637593e-02f, 1.043637593e-02f, 1.043637593e-02f, 1.043637593e-02f,
        1.624820318e-01f, 1.624820318e-01f, 1.624820318e-01f, 1.624820318e-01f,
        7.961564959e-01f, 7.961564959e-01f, 7.961564959e-01f, 7.961564959e-01f,
        8.210152774e-01f, 8.210152774e-01f, 8.210152774e-01f, 8.210152774e-01f,
    };
    HWY_ALIGN constexpr float q[(4 + 1) * 4] = {
        2.631846970e-01f,  2.631846970e-01f,  2.631846970e-01f,
        2.631846970e-01f,  1.076976492e+00f,  1.076976492e+00f,
        1.076976492e+00f,  1.076976492e+00f,  4.987528350e-01f,
        4.987528350e-01f,  4.987528350e-01f,  4.987528350e-01f,
        -5.512498495e-02f, -5.512498495e-02f, -5.512498495e-02f,
        -5.512498495e-02f, 6.521209011e-03f,  6.521209011e-03f,
        6.521209011e-03f,  6.521209011e-03f,
    };
    const V linear = Mul(x, Set(d, kLowDivInv));
    const V poly = EvalRationalPolynomial(d, x, p, q);
    const V magnitude =
        IfThenElse(Gt(x, Set(d, kThreshSRGBToLinear)), poly, linear);
    return Or(AndNot(kSign, magnitude), original_sign);
  }

  // Error ~5e-07
  template <class D, class V>
  JXL_INLINE V EncodedFromDisplay(D d, V x) const {
    const hwy::HWY_NAMESPACE::Rebind<uint32_t, D> du;
    const V kSign = BitCast(d, Set(du, 0x80000000u));
    const V original_sign = And(x, kSign);
    x = AndNot(kSign, x);  // abs

    // Computed via af_cheb_rational (k=100); replicated 4x.
    HWY_ALIGN constexpr float p[(4 + 1) * 4] = {
        -5.135152395e-04f, -5.135152395e-04f, -5.135152395e-04f,
        -5.135152395e-04f, 5.287254571e-03f,  5.287254571e-03f,
        5.287254571e-03f,  5.287254571e-03f,  3.903842876e-01f,
        3.903842876e-01f,  3.903842876e-01f,  3.903842876e-01f,
        1.474205315e+00f,  1.474205315e+00f,  1.474205315e+00f,
        1.474205315e+00f,  7.352629620e-01f,  7.352629620e-01f,
        7.352629620e-01f,  7.352629620e-01f,
    };
    HWY_ALIGN constexpr float q[(4 + 1) * 4] = {
        1.004519624e-02f, 1.004519624e-02f, 1.004519624e-02f, 1.004519624e-02f,
        3.036675394e-01f, 3.036675394e-01f, 3.036675394e-01f, 3.036675394e-01f,
        1.340816930e+00f, 1.340816930e+00f, 1.340816930e+00f, 1.340816930e+00f,
        9.258482155e-01f, 9.258482155e-01f, 9.258482155e-01f, 9.258482155e-01f,
        2.424867759e-02f, 2.424867759e-02f, 2.424867759e-02f, 2.424867759e-02f,
    };
    const V linear = Mul(x, Set(d, kLowDiv));
    const V poly = EvalRationalPolynomial(d, Sqrt(x), p, q);
    const V magnitude =
        IfThenElse(Gt(x, Set(d, kThreshLinearToSRGB)), poly, linear);
    return Or(AndNot(kSign, magnitude), original_sign);
  }

 private:
  static constexpr float kThreshSRGBToLinear = 0.04045f;
  static constexpr float kThreshLinearToSRGB = 0.0031308f;
  static constexpr float kLowDiv = 12.92f;
  static constexpr float kLowDivInv = 1.0f / kLowDiv;
};

// Linear to sRGB conversion with error of at most 1.2e-4.
template <typename D, typename V>
V FastLinearToSRGB(D d, V v) {
  const hwy::HWY_NAMESPACE::Rebind<uint32_t, D> du;
  const hwy::HWY_NAMESPACE::Rebind<int32_t, D> di;
  // Convert to 0.25 - 0.5 range.
  auto v025_05 = BitCast(
      d, And(Or(BitCast(du, v), Set(du, 0x3e800000)), Set(du, 0x3effffff)));
  // third degree polynomial approximation between 0.25 and 0.5
  // of 1.055/2^(7/2.4) * x^(1/2.4) * 0.5. A degree 4 polynomial only improves
  // accuracy by about 3x.
  auto d1 = MulAdd(v025_05, Set(d, 0.059914046f), Set(d, -0.108894556f));
  auto d2 = MulAdd(d1, v025_05, Set(d, 0.107963754f));
  auto pow = MulAdd(d2, v025_05, Set(d, 0.018092343f));
  // Compute extra multiplier depending on exponent. Valid exponent range for
  // [0.0031308f, 1.0) is 0...8 after subtracting 118.
  // The next three constants contain a representation of the powers of
  // 2**(1/2.4) = 2**(5/12) times two; in particular, bits from 26 to 31 are
  // always the same and in k2to512powers_basebits, and the two arrays contain
  // the next groups of 8 bits. This ends up being a 22-bit representation (with
  // a mantissa of 13 bits). The choice of polynomial to approximate is such
  // that the multiplication factor has the highest 5 bits constant, and that
  // the factor for the lowest possible exponent is a power of two (thus making
  // the additional bits 0, which is used to correctly merge back together the
  // floats).
  constexpr uint32_t k2to512powers_basebits = 0x40000000;
  HWY_ALIGN constexpr uint8_t k2to512powers_25to18bits[16] = {
      0x0,  0xa,  0x19, 0x26, 0x32, 0x41, 0x4d, 0x5c,
      0x68, 0x75, 0x83, 0x8f, 0xa0, 0xaa, 0xb9, 0xc6,
  };
  HWY_ALIGN constexpr uint8_t k2to512powers_17to10bits[16] = {
      0x0,  0xb7, 0x4,  0xd,  0xcb, 0xe7, 0x41, 0x68,
      0x51, 0xd1, 0xeb, 0xf2, 0x0,  0xb7, 0x4,  0xd,
  };
  // Note that vld1q_s8_x2 on ARM seems to actually be slower.
#if HWY_TARGET != HWY_SCALAR
  using hwy::HWY_NAMESPACE::ShiftLeft;
  using hwy::HWY_NAMESPACE::ShiftRight;
  // Every lane of exp is now (if cast to byte) {0, 0, 0, <index for lookup>}.
  auto exp = Sub(ShiftRight<23>(BitCast(di, v)), Set(di, 118));
  auto pow25to18bits = TableLookupBytes(
      LoadDup128(di,
                 reinterpret_cast<const int32_t*>(k2to512powers_25to18bits)),
      exp);
  auto pow17to10bits = TableLookupBytes(
      LoadDup128(di,
                 reinterpret_cast<const int32_t*>(k2to512powers_17to10bits)),
      exp);
  // Now, pow* contain {0, 0, 0, <part of float repr of multiplier>}. Here
  // we take advantage of the fact that each table has its position 0 equal to
  // 0.
  // We can now just reassemble the float.
  auto mul = BitCast(
      d, Or(Or(ShiftLeft<18>(pow25to18bits), ShiftLeft<10>(pow17to10bits)),
            Set(di, k2to512powers_basebits)));
#else
  // Fallback for scalar.
  uint32_t exp = ((BitCast(di, v).raw >> 23) - 118) & 0xf;
  auto mul = BitCast(d, Set(di, (k2to512powers_25to18bits[exp] << 18) |
                                    (k2to512powers_17to10bits[exp] << 10) |
                                    k2to512powers_basebits));
#endif
  return IfThenElse(Lt(v, Set(d, 0.0031308f)), Mul(v, Set(d, 12.92f)),
                    MulAdd(pow, mul, Set(d, -0.055)));
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#endif  // LIB_JXL_TRANSFER_FUNCTIONS_INL_H_
