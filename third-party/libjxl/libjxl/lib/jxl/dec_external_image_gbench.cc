// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "benchmark/benchmark.h"
#include "lib/jxl/dec_external_image.h"
#include "lib/jxl/image_ops.h"

namespace jxl {
namespace {

// Decoder case, interleaves an internal float image.
void BM_DecExternalImage_ConvertImageRGBA(benchmark::State& state) {
  const size_t kNumIter = 5;
  size_t xsize = state.range();
  size_t ysize = state.range();
  size_t num_channels = 4;

  ImageMetadata im;
  im.SetAlphaBits(8);
  ImageBundle ib(&im);
  Image3F color(xsize, ysize);
  ZeroFillImage(&color);
  ib.SetFromImage(std::move(color), ColorEncoding::SRGB());
  ImageF alpha(xsize, ysize);
  ZeroFillImage(&alpha);
  ib.SetAlpha(std::move(alpha));

  const size_t bytes_per_row = xsize * num_channels;
  std::vector<uint8_t> interleaved(bytes_per_row * ysize);

  for (auto _ : state) {
    for (size_t i = 0; i < kNumIter; ++i) {
      JXL_CHECK(ConvertToExternal(
          ib,
          /*bits_per_sample=*/8,
          /*float_out=*/false, num_channels, JXL_NATIVE_ENDIAN,
          /*stride*/ bytes_per_row,
          /*thread_pool=*/nullptr, interleaved.data(), interleaved.size(),
          /*out_callback=*/{},
          /*undo_orientation=*/jxl::Orientation::kIdentity));
    }
  }

  // Pixels per second.
  state.SetItemsProcessed(kNumIter * state.iterations() * xsize * ysize);
  state.SetBytesProcessed(kNumIter * state.iterations() * interleaved.size());
}

BENCHMARK(BM_DecExternalImage_ConvertImageRGBA)
    ->RangeMultiplier(2)
    ->Range(256, 2048);

}  // namespace
}  // namespace jxl
