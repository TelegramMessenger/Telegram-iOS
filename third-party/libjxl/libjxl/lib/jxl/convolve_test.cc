// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/convolve.h"

#include <time.h>

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/convolve_test.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>
#include <hwy/nanobenchmark.h>
#include <hwy/tests/test_util-inl.h>
#include <vector>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/random.h"
#include "lib/jxl/image_ops.h"
#include "lib/jxl/image_test_utils.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

#ifndef JXL_DEBUG_CONVOLVE
#define JXL_DEBUG_CONVOLVE 0
#endif

#include "lib/jxl/convolve-inl.h"

HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {

void TestNeighbors() {
  const Neighbors::D d;
  const Neighbors::V v = Iota(d, 0);
  HWY_ALIGN float actual[hwy::kTestMaxVectorSize / sizeof(float)] = {0};

  HWY_ALIGN float first_l1[hwy::kTestMaxVectorSize / sizeof(float)] = {
      0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14};
  Store(Neighbors::FirstL1(v), d, actual);
  const size_t N = Lanes(d);
  EXPECT_EQ(std::vector<float>(first_l1, first_l1 + N),
            std::vector<float>(actual, actual + N));

#if HWY_TARGET != HWY_SCALAR
  HWY_ALIGN float first_l2[hwy::kTestMaxVectorSize / sizeof(float)] = {
      1, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13};
  Store(Neighbors::FirstL2(v), d, actual);
  EXPECT_EQ(std::vector<float>(first_l2, first_l2 + N),
            std::vector<float>(actual, actual + N));

  HWY_ALIGN float first_l3[hwy::kTestMaxVectorSize / sizeof(float)] = {
      2, 1, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
  Store(Neighbors::FirstL3(v), d, actual);
  EXPECT_EQ(std::vector<float>(first_l3, first_l3 + N),
            std::vector<float>(actual, actual + N));
#endif  // HWY_TARGET != HWY_SCALAR
}

void VerifySymmetric3(const size_t xsize, const size_t ysize, ThreadPool* pool,
                      Rng* rng) {
  const Rect rect(0, 0, xsize, ysize);

  ImageF in(xsize, ysize);
  GenerateImage(*rng, &in, 0.0f, 1.0f);

  ImageF out_expected(xsize, ysize);
  ImageF out_actual(xsize, ysize);

  const WeightsSymmetric3& weights = WeightsSymmetric3Lowpass();
  Symmetric3(in, rect, weights, pool, &out_expected);
  SlowSymmetric3(in, rect, weights, pool, &out_actual);

  JXL_ASSERT_OK(VerifyRelativeError(out_expected, out_actual, 1E-5f, 1E-5f, _));
}

// Ensures Symmetric and Separable give the same result.
void VerifySymmetric5(const size_t xsize, const size_t ysize, ThreadPool* pool,
                      Rng* rng) {
  const Rect rect(0, 0, xsize, ysize);

  ImageF in(xsize, ysize);
  GenerateImage(*rng, &in, 0.0f, 1.0f);

  ImageF out_expected(xsize, ysize);
  ImageF out_actual(xsize, ysize);

  Separable5(in, Rect(in), WeightsSeparable5Lowpass(), pool, &out_expected);
  Symmetric5(in, rect, WeightsSymmetric5Lowpass(), pool, &out_actual);

  JXL_ASSERT_OK(VerifyRelativeError(out_expected, out_actual, 1E-5f, 1E-5f, _));
}

void VerifySeparable5(const size_t xsize, const size_t ysize, ThreadPool* pool,
                      Rng* rng) {
  const Rect rect(0, 0, xsize, ysize);

  ImageF in(xsize, ysize);
  GenerateImage(*rng, &in, 0.0f, 1.0f);

  ImageF out_expected(xsize, ysize);
  ImageF out_actual(xsize, ysize);

  const WeightsSeparable5& weights = WeightsSeparable5Lowpass();
  Separable5(in, Rect(in), weights, pool, &out_expected);
  SlowSeparable5(in, rect, weights, pool, &out_actual);

  JXL_ASSERT_OK(VerifyRelativeError(out_expected, out_actual, 1E-5f, 1E-5f, _));
}

void VerifySeparable7(const size_t xsize, const size_t ysize, ThreadPool* pool,
                      Rng* rng) {
  const Rect rect(0, 0, xsize, ysize);

  ImageF in(xsize, ysize);
  GenerateImage(*rng, &in, 0.0f, 1.0f);

  ImageF out_expected(xsize, ysize);
  ImageF out_actual(xsize, ysize);

  // Gaussian sigma 1.0
  const WeightsSeparable7 weights = {{HWY_REP4(0.383103f), HWY_REP4(0.241843f),
                                      HWY_REP4(0.060626f), HWY_REP4(0.00598f)},
                                     {HWY_REP4(0.383103f), HWY_REP4(0.241843f),
                                      HWY_REP4(0.060626f), HWY_REP4(0.00598f)}};

  SlowSeparable7(in, rect, weights, pool, &out_expected);
  Separable7(in, Rect(in), weights, pool, &out_actual);

  JXL_ASSERT_OK(VerifyRelativeError(out_expected, out_actual, 1E-5f, 1E-5f, _));
}

// For all xsize/ysize and kernels:
void TestConvolve() {
  TestNeighbors();

  test::ThreadPoolForTests pool(4);
  EXPECT_EQ(true,
            RunOnPool(
                &pool, kConvolveMaxRadius, 40, ThreadPool::NoInit,
                [](const uint32_t task, size_t /*thread*/) {
                  const size_t xsize = task;
                  Rng rng(129 + 13 * xsize);

                  ThreadPool* null_pool = nullptr;
                  test::ThreadPoolForTests pool3(3);
                  for (size_t ysize = kConvolveMaxRadius; ysize < 16; ++ysize) {
                    JXL_DEBUG(JXL_DEBUG_CONVOLVE,
                              "%" PRIuS " x %" PRIuS " (target %" PRIx64
                              ")===============================",
                              xsize, ysize, static_cast<int64_t>(HWY_TARGET));

                    JXL_DEBUG(JXL_DEBUG_CONVOLVE, "Sym3------------------");
                    VerifySymmetric3(xsize, ysize, null_pool, &rng);
                    VerifySymmetric3(xsize, ysize, &pool3, &rng);

                    JXL_DEBUG(JXL_DEBUG_CONVOLVE, "Sym5------------------");
                    VerifySymmetric5(xsize, ysize, null_pool, &rng);
                    VerifySymmetric5(xsize, ysize, &pool3, &rng);

                    JXL_DEBUG(JXL_DEBUG_CONVOLVE, "Sep5------------------");
                    VerifySeparable5(xsize, ysize, null_pool, &rng);
                    VerifySeparable5(xsize, ysize, &pool3, &rng);

                    JXL_DEBUG(JXL_DEBUG_CONVOLVE, "Sep7------------------");
                    VerifySeparable7(xsize, ysize, null_pool, &rng);
                    VerifySeparable7(xsize, ysize, &pool3, &rng);
                  }
                },
                "TestConvolve"));
}

// Measures durations, verifies results, prints timings. `unpredictable1`
// must have value 1 (unknown to the compiler to prevent elision).
template <class Conv>
void BenchmarkConv(const char* caption, const Conv& conv,
                   const hwy::FuncInput unpredictable1) {
  const size_t kNumInputs = 1;
  const hwy::FuncInput inputs[kNumInputs] = {unpredictable1};
  hwy::Result results[kNumInputs];

  const size_t kDim = 160;  // in+out fit in L2
  ImageF in(kDim, kDim);
  ZeroFillImage(&in);
  in.Row(kDim / 2)[kDim / 2] = unpredictable1;
  ImageF out(kDim, kDim);

  hwy::Params p;
  p.verbose = false;
  p.max_evals = 7;
  p.target_rel_mad = 0.002;
  const size_t num_results = MeasureClosure(
      [&in, &conv, &out](const hwy::FuncInput input) {
        conv(in, &out);
        return out.Row(input)[0];
      },
      inputs, kNumInputs, results, p);
  if (num_results != kNumInputs) {
    fprintf(stderr, "MeasureClosure failed.\n");
  }
  for (size_t i = 0; i < num_results; ++i) {
    const double seconds = static_cast<double>(results[i].ticks) /
                           hwy::platform::InvariantTicksPerSecond();
    printf("%12s: %7.2f MP/s (MAD=%4.2f%%)\n", caption,
           kDim * kDim * 1E-6 / seconds,
           static_cast<double>(results[i].variability) * 100.0);
  }
}

struct ConvSymmetric3 {
  void operator()(const ImageF& in, ImageF* JXL_RESTRICT out) const {
    ThreadPool* null_pool = nullptr;
    Symmetric3(in, Rect(in), WeightsSymmetric3Lowpass(), null_pool, out);
  }
};

struct ConvSeparable5 {
  void operator()(const ImageF& in, ImageF* JXL_RESTRICT out) const {
    ThreadPool* null_pool = nullptr;
    Separable5(in, Rect(in), WeightsSeparable5Lowpass(), null_pool, out);
  }
};

void BenchmarkAll() {
#if 0  // disabled to avoid test timeouts, run manually on demand
  const hwy::FuncInput unpredictable1 = time(nullptr) != 1234;
  BenchmarkConv("Symmetric3", ConvSymmetric3(), unpredictable1);
  BenchmarkConv("Separable5", ConvSeparable5(), unpredictable1);
#endif
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {

class ConvolveTest : public hwy::TestWithParamTarget {};
HWY_TARGET_INSTANTIATE_TEST_SUITE_P(ConvolveTest);

HWY_EXPORT_AND_TEST_P(ConvolveTest, TestConvolve);

HWY_EXPORT_AND_TEST_P(ConvolveTest, BenchmarkAll);

}  // namespace jxl
#endif
