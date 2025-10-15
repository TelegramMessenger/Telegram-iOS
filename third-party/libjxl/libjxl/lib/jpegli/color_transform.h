// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_COLOR_TRANSFORM_H_
#define LIB_JPEGLI_COLOR_TRANSFORM_H_

#include "lib/jpegli/common.h"
#include "lib/jxl/base/compiler_specific.h"

namespace jpegli {

void ChooseColorTransform(j_compress_ptr cinfo);

void ChooseColorTransform(j_decompress_ptr cinfo);

}  // namespace jpegli

#endif  // LIB_JPEGLI_COLOR_TRANSFORM_H_
