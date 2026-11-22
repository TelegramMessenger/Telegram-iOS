// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_UPSAMPLE_H_
#define LIB_JPEGLI_UPSAMPLE_H_

#include <stddef.h>

#include "lib/jxl/base/compiler_specific.h"

namespace jpegli {

void Upsample2Horizontal(float* JXL_RESTRICT row,
                         float* JXL_RESTRICT scratch_space, size_t len_out);

void Upsample2Vertical(const float* JXL_RESTRICT row_top,
                       const float* JXL_RESTRICT row_mid,
                       const float* JXL_RESTRICT row_bot,
                       float* JXL_RESTRICT row_out0,
                       float* JXL_RESTRICT row_out1, size_t len);

}  // namespace jpegli

#endif  // LIB_JPEGLI_UPSAMPLE_H_
