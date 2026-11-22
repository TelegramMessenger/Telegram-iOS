// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_CONVOLVE_H_
#define LIB_JXL_CONVOLVE_H_

// 2D convolution.

#include <stddef.h>
#include <stdint.h>

#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/image.h"

namespace jxl {

// No valid values outside [0, xsize), but the strategy may still safely load
// the preceding vector, and/or round xsize up to the vector lane count. This
// avoids needing PadImage.
// Requires xsize >= kConvolveLanes + kConvolveMaxRadius.
static constexpr size_t kConvolveMaxRadius = 3;

// Weights must already be normalized.

struct WeightsSymmetric3 {
  // d r d (each replicated 4x)
  // r c r
  // d r d
  float c[4];
  float r[4];
  float d[4];
};

struct WeightsSymmetric5 {
  // The lower-right quadrant is: c r R  (each replicated 4x)
  //                              r d L
  //                              R L D
  float c[4];
  float r[4];
  float R[4];
  float d[4];
  float D[4];
  float L[4];
};

// Weights for separable 5x5 filters (typically but not necessarily the same
// values for horizontal and vertical directions). The kernel must already be
// normalized, but note that values for negative offsets are omitted, so the
// given values do not sum to 1.
struct WeightsSeparable5 {
  // Horizontal 1D, distances 0..2 (each replicated 4x)
  float horz[3 * 4];
  float vert[3 * 4];
};

// Weights for separable 7x7 filters (typically but not necessarily the same
// values for horizontal and vertical directions). The kernel must already be
// normalized, but note that values for negative offsets are omitted, so the
// given values do not sum to 1.
//
// NOTE: for >= 7x7 Gaussian kernels, it is faster to use FastGaussian instead,
// at least when images exceed the L1 cache size.
struct WeightsSeparable7 {
  // Horizontal 1D, distances 0..3 (each replicated 4x)
  float horz[4 * 4];
  float vert[4 * 4];
};

const WeightsSymmetric3& WeightsSymmetric3Lowpass();
const WeightsSeparable5& WeightsSeparable5Lowpass();
const WeightsSymmetric5& WeightsSymmetric5Lowpass();

void SlowSymmetric3(const ImageF& in, const Rect& rect,
                    const WeightsSymmetric3& weights, ThreadPool* pool,
                    ImageF* JXL_RESTRICT out);

void SlowSeparable5(const ImageF& in, const Rect& rect,
                    const WeightsSeparable5& weights, ThreadPool* pool,
                    ImageF* out);

void SlowSeparable7(const ImageF& in, const Rect& rect,
                    const WeightsSeparable7& weights, ThreadPool* pool,
                    ImageF* out);

void Symmetric3(const ImageF& in, const Rect& rect,
                const WeightsSymmetric3& weights, ThreadPool* pool,
                ImageF* out);

void Symmetric5(const ImageF& in, const Rect& rect,
                const WeightsSymmetric5& weights, ThreadPool* pool,
                ImageF* JXL_RESTRICT out);

void Separable5(const ImageF& in, const Rect& rect,
                const WeightsSeparable5& weights, ThreadPool* pool,
                ImageF* out);

void Separable7(const ImageF& in, const Rect& rect,
                const WeightsSeparable7& weights, ThreadPool* pool,
                ImageF* out);

}  // namespace jxl

#endif  // LIB_JXL_CONVOLVE_H_
