// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/hlg.h"

#include <cmath>

#include "lib/jxl/enc_color_management.h"

namespace jxl {

float GetHlgGamma(const float peak_luminance, const float surround_luminance) {
  return 1.2f * std::pow(1.111f, std::log2(peak_luminance / 1000.f)) *
         std::pow(0.98f, std::log2(surround_luminance / 5.f));
}

Status HlgOOTF(ImageBundle* ib, const float gamma, ThreadPool* pool) {
  ColorEncoding linear_rec2020;
  linear_rec2020.SetColorSpace(ColorSpace::kRGB);
  linear_rec2020.primaries = Primaries::k2100;
  linear_rec2020.white_point = WhitePoint::kD65;
  linear_rec2020.tf.SetTransferFunction(TransferFunction::kLinear);
  JXL_RETURN_IF_ERROR(linear_rec2020.CreateICC());
  JXL_RETURN_IF_ERROR(ib->TransformTo(linear_rec2020, GetJxlCms(), pool));

  JXL_RETURN_IF_ERROR(RunOnPool(
      pool, 0, ib->ysize(), ThreadPool::NoInit,
      [&](const int y, const int thread) {
        float* const JXL_RESTRICT rows[3] = {ib->color()->PlaneRow(0, y),
                                             ib->color()->PlaneRow(1, y),
                                             ib->color()->PlaneRow(2, y)};
        for (size_t x = 0; x < ib->xsize(); ++x) {
          float& red = rows[0][x];
          float& green = rows[1][x];
          float& blue = rows[2][x];
          const float luminance =
              0.2627f * red + 0.6780f * green + 0.0593f * blue;
          const float ratio = std::pow(luminance, gamma - 1);
          if (std::isfinite(ratio)) {
            red *= ratio;
            green *= ratio;
            blue *= ratio;
          }
        }
      },
      "HlgOOTF"));
  return true;
}

Status HlgInverseOOTF(ImageBundle* ib, const float gamma, ThreadPool* pool) {
  return HlgOOTF(ib, 1.f / gamma, pool);
}

}  // namespace jxl
