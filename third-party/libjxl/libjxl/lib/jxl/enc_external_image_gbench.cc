// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "benchmark/benchmark.h"
#include "lib/jxl/enc_external_image.h"
#include "lib/jxl/image_ops.h"

namespace jxl {
namespace {

// Encoder case, deinterleaves a buffer.
void BM_EncExternalImage_ConvertImageRGBA(benchmark::State& state) {
  const size_t kNumIter = 5;
  size_t xsize = state.range();
  size_t ysize = state.range();

  ImageMetadata im;
  im.SetAlphaBits(8);
  ImageBundle ib(&im);

  std::vector<uint8_t> interleaved(xsize * ysize * 4);
  JxlPixelFormat format = {4, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};
  for (auto _ : state) {
    for (size_t i = 0; i < kNumIter; ++i) {
      JXL_CHECK(ConvertFromExternal(
          Span<const uint8_t>(interleaved.data(), interleaved.size()), xsize,
          ysize,
          /*c_current=*/ColorEncoding::SRGB(),
          /*bits_per_sample=*/8, format,
          /*pool=*/nullptr, &ib));
    }
  }

  // Pixels per second.
  state.SetItemsProcessed(kNumIter * state.iterations() * xsize * ysize);
  state.SetBytesProcessed(kNumIter * state.iterations() * interleaved.size());
}

BENCHMARK(BM_EncExternalImage_ConvertImageRGBA)
    ->RangeMultiplier(2)
    ->Range(256, 2048);

}  // namespace
}  // namespace jxl
