// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "benchmark/benchmark.h"
#include "lib/jxl/splines.h"

namespace jxl {
namespace {

constexpr int kQuantizationAdjustment = 0;
const ColorCorrelationMap* const cmap = new ColorCorrelationMap;
const float kYToX = cmap->YtoXRatio(0);
const float kYToB = cmap->YtoBRatio(0);

void BM_Splines(benchmark::State& state) {
  const size_t n = state.range();

  std::vector<Spline> spline_data = {
      {/*control_points=*/{
           {9, 54}, {118, 159}, {97, 3}, {10, 40}, {150, 25}, {120, 300}},
       /*color_dct=*/
       {{0.03125f, 0.00625f, 0.003125f}, {1.f, 0.321875f}, {1.f, 0.24375f}},
       /*sigma_dct=*/{0.3125f, 0.f, 0.f, 0.0625f}}};
  std::vector<QuantizedSpline> quantized_splines;
  std::vector<Spline::Point> starting_points;
  for (const Spline& spline : spline_data) {
    quantized_splines.emplace_back(spline, kQuantizationAdjustment, kYToX,
                                   kYToB);
    starting_points.push_back(spline.control_points.front());
  }
  Splines splines(kQuantizationAdjustment, std::move(quantized_splines),
                  std::move(starting_points));

  Image3F drawing_area(320, 320);
  ZeroFillImage(&drawing_area);
  for (auto _ : state) {
    for (size_t i = 0; i < n; ++i) {
      JXL_CHECK(splines.InitializeDrawCache(drawing_area.xsize(),
                                            drawing_area.ysize(), *cmap));
      splines.AddTo(&drawing_area, Rect(drawing_area), Rect(drawing_area));
    }
  }

  state.SetItemsProcessed(n * state.iterations());
}

BENCHMARK(BM_Splines)->Range(1, 1 << 10);

}  // namespace
}  // namespace jxl
