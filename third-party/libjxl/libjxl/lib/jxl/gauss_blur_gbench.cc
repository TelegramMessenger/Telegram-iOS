// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <hwy/targets.h>

#include "benchmark/benchmark.h"
#include "lib/jxl/convolve.h"
#include "lib/jxl/gauss_blur.h"
#include "lib/jxl/image_ops.h"

namespace jxl {
namespace {

JXL_MAYBE_UNUSED ImageF Convolve(const ImageF& in,
                                 const std::vector<float>& kernel) {
  return ConvolveAndSample(in, kernel, 1);
}

void BM_GaussBlur1d(benchmark::State& state) {
  // Uncomment to disable SIMD and force and scalar implementation
  // hwy::DisableTargets(~HWY_SCALAR);
  // Uncomment to run AVX2
  // hwy::DisableTargets(HWY_AVX3);

  const size_t length = state.range();
  const double sigma = 7.0;  // (from Butteraugli application)
  ImageF in(length, 1);
  const float expected = length;
  FillImage(expected, &in);

  ImageF temp(length, 1);
  ImageF out(length, 1);
  const auto rg = CreateRecursiveGaussian(sigma);
  for (auto _ : state) {
    FastGaussian1D(rg, in.Row(0), length, out.Row(0));
    // Prevent optimizing out
    JXL_ASSERT(std::abs(out.ConstRow(0)[length / 2] - expected) / expected <
               9E-5);
  }
  state.SetItemsProcessed(length * state.iterations());
}

void BM_GaussBlur2d(benchmark::State& state) {
  // See GaussBlur1d for SIMD changes.

  const size_t xsize = state.range();
  const size_t ysize = xsize;
  const double sigma = 7.0;  // (from Butteraugli application)
  ImageF in(xsize, ysize);
  const float expected = xsize + ysize;
  FillImage(expected, &in);

  ImageF temp(xsize, ysize);
  ImageF out(xsize, ysize);
  ThreadPool* null_pool = nullptr;
  const auto rg = CreateRecursiveGaussian(sigma);
  for (auto _ : state) {
    FastGaussian(rg, in, null_pool, &temp, &out);
    // Prevent optimizing out
    JXL_ASSERT(std::abs(out.ConstRow(ysize / 2)[xsize / 2] - expected) /
                   expected <
               9E-5);
  }
  state.SetItemsProcessed(xsize * ysize * state.iterations());
}

void BM_GaussBlurFir(benchmark::State& state) {
  // See GaussBlur1d for SIMD changes.

  const size_t xsize = state.range();
  const size_t ysize = xsize;
  const double sigma = 7.0;  // (from Butteraugli application)
  ImageF in(xsize, ysize);
  const float expected = xsize + ysize;
  FillImage(expected, &in);

  ImageF temp(xsize, ysize);
  ImageF out(xsize, ysize);
  const std::vector<float> kernel =
      GaussianKernel(static_cast<int>(4 * sigma), static_cast<float>(sigma));
  for (auto _ : state) {
    // Prevent optimizing out
    JXL_ASSERT(std::abs(Convolve(in, kernel).ConstRow(ysize / 2)[xsize / 2] -
                        expected) /
                   expected <
               9E-5);
  }
  state.SetItemsProcessed(xsize * ysize * state.iterations());
}

void BM_GaussBlurSep7(benchmark::State& state) {
  // See GaussBlur1d for SIMD changes.

  const size_t xsize = state.range();
  const size_t ysize = xsize;
  ImageF in(xsize, ysize);
  const float expected = xsize + ysize;
  FillImage(expected, &in);

  ImageF temp(xsize, ysize);
  ImageF out(xsize, ysize);
  ThreadPool* null_pool = nullptr;
  // Gaussian with sigma 1
  const WeightsSeparable7 weights = {{HWY_REP4(0.383103f), HWY_REP4(0.241843f),
                                      HWY_REP4(0.060626f), HWY_REP4(0.00598f)},
                                     {HWY_REP4(0.383103f), HWY_REP4(0.241843f),
                                      HWY_REP4(0.060626f), HWY_REP4(0.00598f)}};
  for (auto _ : state) {
    Separable7(in, Rect(in), weights, null_pool, &out);
    // Prevent optimizing out
    JXL_ASSERT(std::abs(out.ConstRow(ysize / 2)[xsize / 2] - expected) /
                   expected <
               9E-5);
  }
  state.SetItemsProcessed(xsize * ysize * state.iterations());
}

BENCHMARK(BM_GaussBlur1d)->Range(1 << 8, 1 << 14);
BENCHMARK(BM_GaussBlur2d)->Range(1 << 7, 1 << 10);
BENCHMARK(BM_GaussBlurFir)->Range(1 << 7, 1 << 10);
BENCHMARK(BM_GaussBlurSep7)->Range(1 << 7, 1 << 10);

}  // namespace
}  // namespace jxl
