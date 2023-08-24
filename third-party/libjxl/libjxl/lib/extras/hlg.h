// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_HLG_H_
#define LIB_EXTRAS_HLG_H_

#include "lib/jxl/image_bundle.h"

namespace jxl {

float GetHlgGamma(float peak_luminance, float surround_luminance = 5.f);

Status HlgOOTF(ImageBundle* ib, float gamma, ThreadPool* pool = nullptr);

Status HlgInverseOOTF(ImageBundle* ib, float gamma, ThreadPool* pool = nullptr);

}  // namespace jxl

#endif  // LIB_EXTRAS_HLG_H_
