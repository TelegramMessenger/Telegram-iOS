// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/dec_transforms_testonly.h"

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/dec_transforms_testonly.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jxl/dct_scales.h"
#include "lib/jxl/dec_transforms-inl.h"

namespace jxl {

#if HWY_ONCE
HWY_EXPORT(TransformToPixels);
void TransformToPixels(AcStrategy::Type strategy,
                       float* JXL_RESTRICT coefficients,
                       float* JXL_RESTRICT pixels, size_t pixels_stride,
                       float* scratch_space) {
  return HWY_DYNAMIC_DISPATCH(TransformToPixels)(strategy, coefficients, pixels,
                                                 pixels_stride, scratch_space);
}

HWY_EXPORT(LowestFrequenciesFromDC);
void LowestFrequenciesFromDC(const jxl::AcStrategy::Type strategy,
                             const float* dc, size_t dc_stride, float* llf,
                             float* JXL_RESTRICT scratch) {
  return HWY_DYNAMIC_DISPATCH(LowestFrequenciesFromDC)(strategy, dc, dc_stride,
                                                       llf, scratch);
}

HWY_EXPORT(AFVIDCT4x4);
void AFVIDCT4x4(const float* JXL_RESTRICT coeffs, float* JXL_RESTRICT pixels) {
  return HWY_DYNAMIC_DISPATCH(AFVIDCT4x4)(coeffs, pixels);
}
#endif  // HWY_ONCE

}  // namespace jxl
