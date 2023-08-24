// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>

#include <cmath>
#include <string>

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/rational_polynomial_test.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>
#include <hwy/tests/test_util-inl.h>

#include "lib/jxl/base/status.h"
#include "lib/jxl/common.h"
#include "lib/jxl/rational_polynomial-inl.h"

HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {

using T = float;  // required by EvalLog2
using D = HWY_FULL(T);

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::Add;
using hwy::HWY_NAMESPACE::GetLane;
using hwy::HWY_NAMESPACE::ShiftLeft;
using hwy::HWY_NAMESPACE::ShiftRight;
using hwy::HWY_NAMESPACE::Sub;

// Generic: only computes polynomial
struct EvalPoly {
  template <size_t NP, size_t NQ>
  T operator()(T x, const T (&p)[NP], const T (&q)[NQ]) const {
    const HWY_FULL(T) d;
    const auto vx = Set(d, x);
    const auto approx = EvalRationalPolynomial(d, vx, p, q);
    return GetLane(approx);
  }
};

// Range reduction for log2
struct EvalLog2 {
  template <size_t NP, size_t NQ>
  T operator()(T x, const T (&p)[NP], const T (&q)[NQ]) const {
    const HWY_FULL(T) d;
    auto vx = Set(d, x);

    const HWY_FULL(int32_t) di;
    const auto x_bits = BitCast(di, vx);
    // Cannot handle negative numbers / NaN.
    JXL_DASSERT(AllTrue(di, Eq(Abs(x_bits), x_bits)));

    // Range reduction to [-1/3, 1/3] - 3 integer, 2 float ops
    const auto exp_bits = Sub(x_bits, Set(di, 0x3f2aaaab));  // = 2/3
    // Shifted exponent = log2; also used to clear mantissa.
    const auto exp_shifted = ShiftRight<23>(exp_bits);
    const auto mantissa = BitCast(d, Sub(x_bits, ShiftLeft<23>(exp_shifted)));
    const auto exp_val = ConvertTo(d, exp_shifted);
    vx = Sub(mantissa, Set(d, 1.0f));

    const auto approx = Add(EvalRationalPolynomial(d, vx, p, q), exp_val);
    return GetLane(approx);
  }
};

// Functions to approximate:

T LinearToSrgb8Direct(T val) {
  if (val < 0.0) return 0.0;
  if (val >= 255.0) return 255.0;
  if (val <= 10.0 / 12.92) return val * 12.92;
  return 255.0 * (std::pow(val / 255.0, 1.0 / 2.4) * 1.055 - 0.055);
}

T SimpleGamma(T v) {
  static const T kGamma = 0.387494322593;
  static const T limit = 43.01745241042018;
  T bright = v - limit;
  if (bright >= 0) {
    static const T mul = 0.0383723643799;
    v -= bright * mul;
  }
  static const T limit2 = 94.68634353321337;
  T bright2 = v - limit2;
  if (bright2 >= 0) {
    static const T mul = 0.22885405968;
    v -= bright2 * mul;
  }
  static const T offset = 0.156775786057;
  static const T scale = 8.898059160493739;
  T retval = scale * (offset + pow(v, kGamma));
  return retval;
}

// Runs CaratheodoryFejer and verifies the polynomial using a lot of samples to
// return the biggest error.
template <size_t NP, size_t NQ, class Eval>
T RunApproximation(T x0, T x1, const T (&p)[NP], const T (&q)[NQ],
                   const Eval& eval, T func_to_approx(T)) {
  float maxerr = 0;
  T lastPrint = 0;
  // NOLINTNEXTLINE(clang-analyzer-security.FloatLoopCounter)
  for (T x = x0; x <= x1; x += (x1 - x0) / 10000.0) {
    const T f = func_to_approx(x);
    const T g = eval(x, p, q);
    maxerr = std::max(fabsf(g - f), maxerr);
    if (x == x0 || x - lastPrint > (x1 - x0) / 20.0) {
      printf("x: %11.6f, f: %11.6f, g: %11.6f, e: %11.6f\n", x, f, g,
             fabs(g - f));
      lastPrint = x;
    }
  }
  return maxerr;
}

void TestSimpleGamma() {
  const T p[4 * (6 + 1)] = {
      HWY_REP4(-5.0646949363741811E-05), HWY_REP4(6.7369380528439771E-05),
      HWY_REP4(8.9376652530412794E-05),  HWY_REP4(2.1153513301520462E-06),
      HWY_REP4(-6.9130322970386449E-08), HWY_REP4(3.9424752749293728E-10),
      HWY_REP4(1.2360288207619576E-13)};

  const T q[4 * (6 + 1)] = {
      HWY_REP4(-6.6389733798591366E-06), HWY_REP4(1.3299859726565908E-05),
      HWY_REP4(3.8538748358398873E-06),  HWY_REP4(-2.8707687262928236E-08),
      HWY_REP4(-6.6897385800005434E-10), HWY_REP4(6.1428748869186003E-12),
      HWY_REP4(-2.5475738169252870E-15)};

  const T err = RunApproximation(0.77, 274.579999999999984, p, q, EvalPoly(),
                                 SimpleGamma);
  EXPECT_LT(err, 0.05);
}

void TestLinearToSrgb8Direct() {
  const T p[4 * (5 + 1)] = {
      HWY_REP4(-9.5357499040105154E-05), HWY_REP4(4.6761186249798248E-04),
      HWY_REP4(2.5708174333943594E-04),  HWY_REP4(1.5250087770436082E-05),
      HWY_REP4(1.1946768008931187E-07),  HWY_REP4(5.9916446295972850E-11)};

  const T q[4 * (4 + 1)] = {
      HWY_REP4(1.8932479758079768E-05), HWY_REP4(2.7312342474687321E-05),
      HWY_REP4(4.3901204783327006E-06), HWY_REP4(1.0417787306920273E-07),
      HWY_REP4(3.0084206762140419E-10)};

  const T err =
      RunApproximation(0.77, 255, p, q, EvalPoly(), LinearToSrgb8Direct);
  EXPECT_LT(err, 0.05);
}

void TestExp() {
  const T p[4 * (2 + 1)] = {HWY_REP4(9.6266879665530902E-01),
                            HWY_REP4(4.8961265681586763E-01),
                            HWY_REP4(8.2619259189548433E-02)};
  const T q[4 * (2 + 1)] = {HWY_REP4(9.6259895571622622E-01),
                            HWY_REP4(-4.7272457588933831E-01),
                            HWY_REP4(7.4802088567547664E-02)};
  const T err =
      RunApproximation(-1, 1, p, q, EvalPoly(), [](T x) { return T(exp(x)); });
  EXPECT_LT(err, 1E-4);
}

void TestNegExp() {
  // 4,3 is the min required for monotonicity; max error in 0,10: 751 ppm
  // no benefit for k>50.
  const T p[4 * (4 + 1)] = {
      HWY_REP4(5.9580258551150123E-02), HWY_REP4(-2.5073728806886408E-02),
      HWY_REP4(4.1561830213689248E-03), HWY_REP4(-3.1815408488900372E-04),
      HWY_REP4(9.3866690094906802E-06)};
  const T q[4 * (3 + 1)] = {
      HWY_REP4(5.9579108238812878E-02), HWY_REP4(3.4542074345478582E-02),
      HWY_REP4(8.7263562483501714E-03), HWY_REP4(1.4095109143061216E-03)};

  const T err =
      RunApproximation(0, 10, p, q, EvalPoly(), [](T x) { return T(exp(-x)); });
  EXPECT_LT(err, sizeof(T) == 8 ? 2E-5 : 3E-5);
}

void TestSin() {
  const T p[4 * (6 + 1)] = {
      HWY_REP4(1.5518122109203780E-05),  HWY_REP4(2.3388958643675966E+00),
      HWY_REP4(-8.6705520940849157E-01), HWY_REP4(-1.9702294764873535E-01),
      HWY_REP4(1.2193404314472320E-01),  HWY_REP4(-1.7373966109788839E-02),
      HWY_REP4(7.8829435883034796E-04)};
  const T q[4 * (5 + 1)] = {
      HWY_REP4(2.3394371422557279E+00), HWY_REP4(-8.7028221081288615E-01),
      HWY_REP4(2.0052872219658430E-01), HWY_REP4(-3.2460335995264836E-02),
      HWY_REP4(3.1546157932479282E-03), HWY_REP4(-1.6692542019380155E-04)};

  const T err = RunApproximation(0, Pi<T>(1) * 2, p, q, EvalPoly(),
                                 [](T x) { return T(sin(x)); });
  EXPECT_LT(err, sizeof(T) == 8 ? 5E-4 : 7E-4);
}

void TestLog() {
  HWY_ALIGN const T p[4 * (2 + 1)] = {HWY_REP4(-1.8503833400518310E-06),
                                      HWY_REP4(1.4287160470083755E+00),
                                      HWY_REP4(7.4245873327820566E-01)};
  HWY_ALIGN const T q[4 * (2 + 1)] = {HWY_REP4(9.9032814277590719E-01),
                                      HWY_REP4(1.0096718572241148E+00),
                                      HWY_REP4(1.7409343003366853E-01)};
  const T err = RunApproximation(1E-6, 1000, p, q, EvalLog2(), std::log2);
  printf("%E\n", err);
}

HWY_NOINLINE void TestRationalPolynomial() {
  TestSimpleGamma();
  TestLinearToSrgb8Direct();
  TestExp();
  TestNegExp();
  TestSin();
  TestLog();
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {

class RationalPolynomialTest : public hwy::TestWithParamTarget {};
HWY_TARGET_INSTANTIATE_TEST_SUITE_P(RationalPolynomialTest);

HWY_EXPORT_AND_TEST_P(RationalPolynomialTest, TestSimpleGamma);
HWY_EXPORT_AND_TEST_P(RationalPolynomialTest, TestLinearToSrgb8Direct);
HWY_EXPORT_AND_TEST_P(RationalPolynomialTest, TestExp);
HWY_EXPORT_AND_TEST_P(RationalPolynomialTest, TestNegExp);
HWY_EXPORT_AND_TEST_P(RationalPolynomialTest, TestSin);
HWY_EXPORT_AND_TEST_P(RationalPolynomialTest, TestLog);

}  // namespace jxl
#endif  // HWY_ONCE
