// Copyright 2020 Google LLC
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

#include <stdio.h>

#include <cfloat>  // FLT_MAX
#include <cmath>   // std::abs

// clang-format off
#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "hwy/contrib/math/math_test.cc"
#include "hwy/foreach_target.h"  // IWYU pragma: keep
#include "hwy/highway.h"
#include "hwy/contrib/math/math-inl.h"
#include "hwy/tests/test_util-inl.h"
// clang-format on

HWY_BEFORE_NAMESPACE();
namespace hwy {
namespace HWY_NAMESPACE {

// We have had test failures caused by excess precision due to keeping
// intermediate results in 80-bit x87 registers. One such failure mode is that
// Log1p computes a 1.0 which is not exactly equal to 1.0f, causing is_pole to
// incorrectly evaluate to false.
#undef HWY_MATH_TEST_EXCESS_PRECISION
#if HWY_ARCH_X86_32 && HWY_COMPILER_GCC_ACTUAL && \
    (HWY_TARGET == HWY_SCALAR || HWY_TARGET == HWY_EMU128)

// On 32-bit x86 with GCC 13+, build with `-fexcess-precision=standard` - see
// https://gcc.gnu.org/bugzilla/show_bug.cgi?id=323.
#if HWY_COMPILER_GCC_ACTUAL >= 1300

#if FLT_EVAL_METHOD == 0  // correct flag given, no problem
#define HWY_MATH_TEST_EXCESS_PRECISION 0
#else
#define HWY_MATH_TEST_EXCESS_PRECISION 1
#pragma message( \
    "Skipping scalar math_test on 32-bit x86 GCC 13+ without -fexcess-precision=standard")
#endif  // FLT_EVAL_METHOD

#else                  // HWY_COMPILER_GCC_ACTUAL < 1300

// On 32-bit x86 with GCC <13, set HWY_CMAKE_SSE2 - see
// https://stackoverflow.com/questions/20869904/c-handling-of-excess-precision .
#if defined(__SSE2__)  // correct flag given, no problem
#define HWY_MATH_TEST_EXCESS_PRECISION 0
#else
#define HWY_MATH_TEST_EXCESS_PRECISION 1
#pragma message( \
    "Skipping scalar math_test on 32-bit x86 GCC <13 without HWY_CMAKE_SSE2")
#endif  // defined(__SSE2__)

#endif  // HWY_COMPILER_GCC_ACTUAL
#else   // not (x86-32, GCC, scalar target): running math_test normally
#define HWY_MATH_TEST_EXCESS_PRECISION 0
#endif  // HWY_ARCH_X86_32 etc

template <class Out, class In>
inline Out BitCast(const In& in) {
  static_assert(sizeof(Out) == sizeof(In), "");
  Out out;
  CopyBytes<sizeof(out)>(&in, &out);
  return out;
}

template <class T, class D>
HWY_NOINLINE void TestMath(const char* name, T (*fx1)(T),
                           Vec<D> (*fxN)(D, VecArg<Vec<D>>), D d, T min, T max,
                           uint64_t max_error_ulp) {
  if (HWY_MATH_TEST_EXCESS_PRECISION) {
    static bool once = true;
    if (once) {
      once = false;
      fprintf(stderr,
              "Skipping math_test due to GCC issue with excess precision.\n");
    }
  }

  using UintT = MakeUnsigned<T>;

  const UintT min_bits = BitCast<UintT>(min);
  const UintT max_bits = BitCast<UintT>(max);

  // If min is negative and max is positive, the range needs to be broken into
  // two pieces, [+0, max] and [-0, min], otherwise [min, max].
  int range_count = 1;
  UintT ranges[2][2] = {{min_bits, max_bits}, {0, 0}};
  if ((min < 0.0) && (max > 0.0)) {
    ranges[0][0] = BitCast<UintT>(static_cast<T>(+0.0));
    ranges[0][1] = max_bits;
    ranges[1][0] = BitCast<UintT>(static_cast<T>(-0.0));
    ranges[1][1] = min_bits;
    range_count = 2;
  }

  uint64_t max_ulp = 0;
  // Emulation is slower, so cannot afford as many.
  constexpr UintT kSamplesPerRange = static_cast<UintT>(AdjustedReps(4000));
  for (int range_index = 0; range_index < range_count; ++range_index) {
    const UintT start = ranges[range_index][0];
    const UintT stop = ranges[range_index][1];
    const UintT step = HWY_MAX(1, ((stop - start) / kSamplesPerRange));
    for (UintT value_bits = start; value_bits <= stop; value_bits += step) {
      // For reasons unknown, the HWY_MAX is necessary on RVV, otherwise
      // value_bits can be less than start, and thus possibly NaN.
      const T value = BitCast<T>(HWY_MIN(HWY_MAX(start, value_bits), stop));
      const T actual = GetLane(fxN(d, Set(d, value)));
      const T expected = fx1(value);

      // Skip small inputs and outputs on armv7, it flushes subnormals to zero.
#if HWY_TARGET <= HWY_NEON_WITHOUT_AES && HWY_ARCH_ARM_V7
      if ((std::abs(value) < 1e-37f) || (std::abs(expected) < 1e-37f)) {
        continue;
      }
#endif

      const auto ulp = hwy::detail::ComputeUlpDelta(actual, expected);
      max_ulp = HWY_MAX(max_ulp, ulp);
      if (ulp > max_error_ulp) {
        fprintf(stderr, "%s: %s(%f) expected %f actual %f ulp %g max ulp %u\n",
                hwy::TypeName(T(), Lanes(d)).c_str(), name, value, expected,
                actual, static_cast<double>(ulp),
                static_cast<uint32_t>(max_error_ulp));
      }
    }
  }
  fprintf(stderr, "%s: %s max_ulp %g\n", hwy::TypeName(T(), Lanes(d)).c_str(),
          name, static_cast<double>(max_ulp));
  HWY_ASSERT(max_ulp <= max_error_ulp);
}

#define DEFINE_MATH_TEST_FUNC(NAME)                     \
  HWY_NOINLINE void TestAll##NAME() {                   \
    ForFloat3264Types(ForPartialVectors<Test##NAME>()); \
  }

#undef DEFINE_MATH_TEST
#define DEFINE_MATH_TEST(NAME, F32x1, F32xN, F32_MIN, F32_MAX, F32_ERROR, \
                         F64x1, F64xN, F64_MIN, F64_MAX, F64_ERROR)       \
  struct Test##NAME {                                                     \
    template <class T, class D>                                           \
    HWY_NOINLINE void operator()(T, D d) {                                \
      if (sizeof(T) == 4) {                                               \
        TestMath<T, D>(HWY_STR(NAME), F32x1, F32xN, d, F32_MIN, F32_MAX,  \
                       F32_ERROR);                                        \
      } else {                                                            \
        TestMath<T, D>(HWY_STR(NAME), F64x1, F64xN, d,                    \
                       static_cast<T>(F64_MIN), static_cast<T>(F64_MAX),  \
                       F64_ERROR);                                        \
      }                                                                   \
    }                                                                     \
  };                                                                      \
  DEFINE_MATH_TEST_FUNC(NAME)

// Floating point values closest to but less than 1.0
const float kNearOneF = BitCast<float>(0x3F7FFFFF);
const double kNearOneD = BitCast<double>(0x3FEFFFFFFFFFFFFFULL);

// The discrepancy is unacceptably large for MSYS2 (less accurate libm?), so
// only increase the error tolerance there.
constexpr uint64_t Cos64ULP() {
#if defined(__MINGW32__)
  return 23;
#else
  return 3;
#endif
}

constexpr uint64_t ACosh32ULP() {
#if defined(__MINGW32__)
  return 8;
#else
  return 3;
#endif
}

template <class D>
static Vec<D> SinCosSin(const D d, VecArg<Vec<D>> x) {
  Vec<D> s, c;
  SinCos(d, x, s, c);
  return s;
}

template <class D>
static Vec<D> SinCosCos(const D d, VecArg<Vec<D>> x) {
  Vec<D> s, c;
  SinCos(d, x, s, c);
  return c;
}

// on targets without FMA the result is less inaccurate
constexpr uint64_t SinCosSin32ULP() {
#if !(HWY_NATIVE_FMA)
  return 256;
#else
  return 3;
#endif
}

constexpr uint64_t SinCosCos32ULP() {
#if !(HWY_NATIVE_FMA)
  return 64;
#else
  return 3;
#endif
}

// clang-format off
DEFINE_MATH_TEST(Acos,
  std::acos,  CallAcos,  -1.0f,      +1.0f,       3,  // NEON is 3 instead of 2
  std::acos,  CallAcos,  -1.0,       +1.0,        2)
DEFINE_MATH_TEST(Acosh,
  std::acosh, CallAcosh, +1.0f,      +FLT_MAX,    ACosh32ULP(),
  std::acosh, CallAcosh, +1.0,       +DBL_MAX,    3)
DEFINE_MATH_TEST(Asin,
  std::asin,  CallAsin,  -1.0f,      +1.0f,       4,  // 4 ulp on Armv7, not 2
  std::asin,  CallAsin,  -1.0,       +1.0,        2)
DEFINE_MATH_TEST(Asinh,
  std::asinh, CallAsinh, -FLT_MAX,   +FLT_MAX,    3,
  std::asinh, CallAsinh, -DBL_MAX,   +DBL_MAX,    3)
DEFINE_MATH_TEST(Atan,
  std::atan,  CallAtan,  -FLT_MAX,   +FLT_MAX,    3,
  std::atan,  CallAtan,  -DBL_MAX,   +DBL_MAX,    3)
DEFINE_MATH_TEST(Atanh,
  std::atanh, CallAtanh, -kNearOneF, +kNearOneF,  4,  // NEON is 4 instead of 3
  std::atanh, CallAtanh, -kNearOneD, +kNearOneD,  3)
DEFINE_MATH_TEST(Cos,
  std::cos,   CallCos,   -39000.0f,  +39000.0f,   3,
  std::cos,   CallCos,   -39000.0,   +39000.0,    Cos64ULP())
DEFINE_MATH_TEST(Exp,
  std::exp,   CallExp,   -FLT_MAX,   +104.0f,     1,
  std::exp,   CallExp,   -DBL_MAX,   +104.0,      1)
DEFINE_MATH_TEST(Expm1,
  std::expm1, CallExpm1, -FLT_MAX,   +104.0f,     4,
  std::expm1, CallExpm1, -DBL_MAX,   +104.0,      4)
DEFINE_MATH_TEST(Log,
  std::log,   CallLog,   +FLT_MIN,   +FLT_MAX,    1,
  std::log,   CallLog,   +DBL_MIN,   +DBL_MAX,    1)
DEFINE_MATH_TEST(Log10,
  std::log10, CallLog10, +FLT_MIN,   +FLT_MAX,    2,
  std::log10, CallLog10, +DBL_MIN,   +DBL_MAX,    2)
DEFINE_MATH_TEST(Log1p,
  std::log1p, CallLog1p, +0.0f,      +1e37f,      3,  // NEON is 3 instead of 2
  std::log1p, CallLog1p, +0.0,       +DBL_MAX,    2)
DEFINE_MATH_TEST(Log2,
  std::log2,  CallLog2,  +FLT_MIN,   +FLT_MAX,    2,
  std::log2,  CallLog2,  +DBL_MIN,   +DBL_MAX,    2)
DEFINE_MATH_TEST(Sin,
  std::sin,   CallSin,   -39000.0f,  +39000.0f,   3,
  std::sin,   CallSin,   -39000.0,   +39000.0,    4)  // MSYS is 4 instead of 3
DEFINE_MATH_TEST(Sinh,
  std::sinh,  CallSinh,  -80.0f,     +80.0f,      4,
  std::sinh,  CallSinh,  -709.0,     +709.0,      4)
DEFINE_MATH_TEST(Tanh,
  std::tanh,  CallTanh,  -FLT_MAX,   +FLT_MAX,    4,
  std::tanh,  CallTanh,  -DBL_MAX,   +DBL_MAX,    4)
DEFINE_MATH_TEST(SinCosSin,
  std::sin,   SinCosSin,   -39000.0f,  +39000.0f,   SinCosSin32ULP(),
  std::sin,   SinCosSin,   -39000.0,   +39000.0,    1)
DEFINE_MATH_TEST(SinCosCos,
  std::cos,   SinCosCos,   -39000.0f,  +39000.0f,   SinCosCos32ULP(),
  std::cos,   SinCosCos,   -39000.0,   +39000.0,    1)
// clang-format on

template <typename T, class D>
void Atan2TestCases(T /*unused*/, D d, size_t& padded,
                    AlignedFreeUniquePtr<T[]>& out_y,
                    AlignedFreeUniquePtr<T[]>& out_x,
                    AlignedFreeUniquePtr<T[]>& out_expected) {
  struct YX {
    T y;
    T x;
    T expected;
  };
  const T pos = static_cast<T>(1E5);
  const T neg = static_cast<T>(-1E7);
  // T{-0} is not enough to get an actual negative zero.
  const T n0 = static_cast<T>(-0.0);
  const T inf = GetLane(Inf(d));
  const T nan = GetLane(NaN(d));

  const T pi = static_cast<T>(3.141592653589793238);
  const YX test_cases[] = {                                  // 45 degree steps:
                           {T{0.0}, T{1.0}, T{0}},           // E
                           {T{-1.0}, T{1.0}, -pi / 4},       // SE
                           {T{-1.0}, T{0.0}, -pi / 2},       // S
                           {T{-1.0}, T{-1.0}, -3 * pi / 4},  // SW
                           {T{0.0}, T{-1.0}, pi},            // W
                           {T{1.0}, T{-1.0}, 3 * pi / 4},    // NW
                           {T{1.0}, T{0.0}, pi / 2},         // N
                           {T{1.0}, T{1.0}, pi / 4},         // NE

                           // y = ±0, x < 0 or -0
                           {T{0}, T{-1}, pi},
                           {n0, T{-2}, -pi},
                           // y = ±0, x > 0 or +0
                           {T{0}, T{2}, T{0}},
                           {n0, T{2}, n0},
                           // y = ±∞, x finite
                           {inf, T{3}, pi / 2},
                           {-inf, T{3}, -pi / 2},
                           // y = ±∞, x = -∞
                           {inf, -inf, 3 * pi / 4},
                           {-inf, -inf, -3 * pi / 4},
                           // y = ±∞, x = +∞
                           {inf, inf, pi / 4},
                           {-inf, inf, -pi / 4},
                           // y < 0, x = ±0
                           {T{-2}, T{0}, -pi / 2},
                           {T{-1}, n0, -pi / 2},
                           // y > 0, x = ±0
                           {pos, T{0}, pi / 2},
                           {T{4}, n0, pi / 2},
                           // finite y > 0, x = -∞
                           {pos, -inf, pi},
                           // finite y < 0, x = -∞
                           {neg, -inf, -pi},
                           // finite y > 0, x = +∞
                           {pos, inf, T{0}},
                           // finite y < 0, x = +∞
                           {neg, inf, n0},
                           // y NaN xor x NaN
                           {nan, T{0}, nan},
                           {pos, nan, nan}};
  const size_t kNumTestCases = sizeof(test_cases) / sizeof(test_cases[0]);
  const size_t N = Lanes(d);
  padded = RoundUpTo(kNumTestCases, N);  // allow loading whole vectors
  out_y = AllocateAligned<T>(padded);
  out_x = AllocateAligned<T>(padded);
  out_expected = AllocateAligned<T>(padded);
  HWY_ASSERT(out_y && out_x);
  size_t i = 0;
  for (; i < kNumTestCases; ++i) {
    out_y[i] = test_cases[i].y;
    out_x[i] = test_cases[i].x;
    out_expected[i] = test_cases[i].expected;
  }
  for (; i < padded; ++i) {
    out_y[i] = T{0};
    out_x[i] = T{0};
    out_expected[i] = T{0};
  }
}

struct TestAtan2 {
  template <typename T, class D>
  HWY_NOINLINE void operator()(T t, D d) {
    const size_t N = Lanes(d);

    size_t padded;
    AlignedFreeUniquePtr<T[]> in_y, in_x, expected;
    Atan2TestCases(t, d, padded, in_y, in_x, expected);

    const Vec<D> tolerance = Set(d, T(1E-5));

    for (size_t i = 0; i < padded; ++i) {
      const T actual = static_cast<T>(atan2(in_y[i], in_x[i]));
      // fprintf(stderr, "%zu: table %f atan2 %f\n", i, expected[i], actual);
      HWY_ASSERT_EQ(expected[i], actual);
    }
    for (size_t i = 0; i < padded; i += N) {
      const Vec<D> y = Load(d, &in_y[i]);
      const Vec<D> x = Load(d, &in_x[i]);
#if HWY_ARCH_ARM_A64
      // TODO(b/287462770): inline to work around incorrect SVE codegen
      const Vec<D> actual = Atan2(d, y, x);
#else
      const Vec<D> actual = CallAtan2(d, y, x);
#endif
      const Vec<D> vexpected = Load(d, &expected[i]);

      const Mask<D> exp_nan = IsNaN(vexpected);
      const Mask<D> act_nan = IsNaN(actual);
      HWY_ASSERT_MASK_EQ(d, exp_nan, act_nan);

      // If not NaN, then compare with tolerance
      const Mask<D> ge = Ge(actual, Sub(vexpected, tolerance));
      const Mask<D> le = Le(actual, Add(vexpected, tolerance));
      const Mask<D> ok = Or(act_nan, And(le, ge));
      if (!AllTrue(d, ok)) {
        const size_t mismatch =
            static_cast<size_t>(FindKnownFirstTrue(d, Not(ok)));
        fprintf(stderr, "Mismatch for i=%d expected %f actual %f\n",
                static_cast<int>(i + mismatch), expected[i + mismatch],
                ExtractLane(actual, mismatch));
        HWY_ASSERT(0);
      }
    }
  }
};

HWY_NOINLINE void TestAllAtan2() {
  if (HWY_MATH_TEST_EXCESS_PRECISION) return;

  ForFloat3264Types(ForPartialVectors<TestAtan2>());
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace hwy
HWY_AFTER_NAMESPACE();

#if HWY_ONCE

namespace hwy {
HWY_BEFORE_TEST(HwyMathTest);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllAcos);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllAcosh);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllAsin);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllAsinh);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllAtan);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllAtanh);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllCos);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllExp);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllExpm1);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllLog);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllLog10);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllLog1p);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllLog2);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllSin);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllSinh);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllTanh);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllAtan2);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllSinCosSin);
HWY_EXPORT_AND_TEST_P(HwyMathTest, TestAllSinCosCos);
}  // namespace hwy

#endif
