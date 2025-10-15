// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/dec_noise.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <algorithm>
#include <numeric>
#include <utility>

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/dec_noise.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/chroma_from_luma.h"
#include "lib/jxl/image_ops.h"
#include "lib/jxl/opsin_params.h"
#include "lib/jxl/sanitizers.h"
#include "lib/jxl/xorshift128plus-inl.h"
HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::Or;
using hwy::HWY_NAMESPACE::ShiftRight;
using hwy::HWY_NAMESPACE::Vec;

using D = HWY_CAPPED(float, kBlockDim);
using DI = hwy::HWY_NAMESPACE::Rebind<int, D>;
using DI8 = hwy::HWY_NAMESPACE::Repartition<uint8_t, D>;

// Converts one vector's worth of random bits to floats in [1, 2).
// NOTE: as the convolution kernel sums to 0, it doesn't matter if inputs are in
// [0, 1) or in [1, 2).
void BitsToFloat(const uint32_t* JXL_RESTRICT random_bits,
                 float* JXL_RESTRICT floats) {
  const HWY_FULL(float) df;
  const HWY_FULL(uint32_t) du;

  const auto bits = Load(du, random_bits);
  // 1.0 + 23 random mantissa bits = [1, 2)
  const auto rand12 = BitCast(df, Or(ShiftRight<9>(bits), Set(du, 0x3F800000)));
  Store(rand12, df, floats);
}

void RandomImage(Xorshift128Plus* rng, const Rect& rect,
                 ImageF* JXL_RESTRICT noise) {
  const size_t xsize = rect.xsize();
  const size_t ysize = rect.ysize();

  // May exceed the vector size, hence we have two loops over x below.
  constexpr size_t kFloatsPerBatch =
      Xorshift128Plus::N * sizeof(uint64_t) / sizeof(float);
  HWY_ALIGN uint64_t batch[Xorshift128Plus::N] = {};

  const HWY_FULL(float) df;
  const size_t N = Lanes(df);

  for (size_t y = 0; y < ysize; ++y) {
    float* JXL_RESTRICT row = rect.Row(noise, y);

    size_t x = 0;
    // Only entire batches (avoids exceeding the image padding).
    for (; x + kFloatsPerBatch < xsize; x += kFloatsPerBatch) {
      rng->Fill(batch);
      for (size_t i = 0; i < kFloatsPerBatch; i += Lanes(df)) {
        BitsToFloat(reinterpret_cast<const uint32_t*>(batch) + i, row + x + i);
      }
    }

    // Any remaining pixels, rounded up to vectors (safe due to padding).
    rng->Fill(batch);
    size_t batch_pos = 0;  // < kFloatsPerBatch
    for (; x < xsize; x += N) {
      BitsToFloat(reinterpret_cast<const uint32_t*>(batch) + batch_pos,
                  row + x);
      batch_pos += N;
    }
  }
}
void Random3Planes(size_t visible_frame_index, size_t nonvisible_frame_index,
                   size_t x0, size_t y0, const std::pair<ImageF*, Rect>& plane0,
                   const std::pair<ImageF*, Rect>& plane1,
                   const std::pair<ImageF*, Rect>& plane2) {
  HWY_ALIGN Xorshift128Plus rng(visible_frame_index, nonvisible_frame_index, x0,
                                y0);
  RandomImage(&rng, plane0.second, plane0.first);
  RandomImage(&rng, plane1.second, plane1.first);
  RandomImage(&rng, plane2.second, plane2.first);
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {

HWY_EXPORT(Random3Planes);
void Random3Planes(size_t visible_frame_index, size_t nonvisible_frame_index,
                   size_t x0, size_t y0, const std::pair<ImageF*, Rect>& plane0,
                   const std::pair<ImageF*, Rect>& plane1,
                   const std::pair<ImageF*, Rect>& plane2) {
  return HWY_DYNAMIC_DISPATCH(Random3Planes)(visible_frame_index,
                                             nonvisible_frame_index, x0, y0,
                                             plane0, plane1, plane2);
}

void DecodeFloatParam(float precision, float* val, BitReader* br) {
  const int absval_quant = br->ReadFixedBits<10>();
  *val = absval_quant / precision;
}

Status DecodeNoise(BitReader* br, NoiseParams* noise_params) {
  for (float& i : noise_params->lut) {
    DecodeFloatParam(kNoisePrecision, &i, br);
  }
  return true;
}

}  // namespace jxl
#endif  // HWY_ONCE
