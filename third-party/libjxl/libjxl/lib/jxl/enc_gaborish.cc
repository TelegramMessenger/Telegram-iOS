// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_gaborish.h"

#include <stddef.h>

#include <hwy/base.h>

#include "lib/jxl/base/status.h"
#include "lib/jxl/convolve.h"
#include "lib/jxl/image_ops.h"

namespace jxl {

void GaborishInverse(Image3F* in_out, float mul[3], ThreadPool* pool) {
  WeightsSymmetric5 weights[3];
  // Only an approximation. One or even two 3x3, and rank-1 (separable) 5x5
  // are insufficient. The numbers here have been obtained by butteraugli
  // based optimizing the whole system and the errors produced are likely
  // more favorable for good rate-distortion compromises rather than
  // just using mathematical optimization to find the inverse.
  static const float kGaborish[5] = {
      -0.090881924078487886f, -0.043663953593472138f, 0.01392497846646211f,
      0.0036189602184591141f, 0.0030557936884763499f};
  for (int i = 0; i < 3; ++i) {
    double sum = 1.0 + mul[i] * 4 *
                           (kGaborish[0] + kGaborish[1] + kGaborish[2] +
                            kGaborish[4] + 2 * kGaborish[3]);
    if (sum < 1e-5) {
      sum = 1e-5;
    }
    const float normalize = static_cast<float>(1.0 / sum);
    const float normalize_mul = mul[i] * normalize;
    weights[i] = WeightsSymmetric5{{HWY_REP4(normalize)},
                                   {HWY_REP4(normalize_mul * kGaborish[0])},
                                   {HWY_REP4(normalize_mul * kGaborish[2])},
                                   {HWY_REP4(normalize_mul * kGaborish[1])},
                                   {HWY_REP4(normalize_mul * kGaborish[4])},
                                   {HWY_REP4(normalize_mul * kGaborish[3])}};
  }
  // Reduce memory footprint by only allocating a single plane and swapping it
  // into the output Image3F. Better still would be tiling.
  // Note that we cannot *allocate* a plane, as doing so might cause Image3F to
  // have planes of different stride. Instead, we copy one plane in a temporary
  // image and reuse the existing planes of the in/out image.
  ImageF temp(in_out->Plane(2).xsize(), in_out->Plane(2).ysize());
  CopyImageTo(in_out->Plane(2), &temp);
  Symmetric5(in_out->Plane(0), Rect(*in_out), weights[0], pool,
             &in_out->Plane(2));
  Symmetric5(in_out->Plane(1), Rect(*in_out), weights[1], pool,
             &in_out->Plane(0));
  Symmetric5(temp, Rect(*in_out), weights[2], pool, &in_out->Plane(1));
  // Now planes are 1, 2, 0.
  in_out->Plane(0).Swap(in_out->Plane(1));
  // 2 1 0
  in_out->Plane(0).Swap(in_out->Plane(2));
}

}  // namespace jxl
