// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_DOWNSAMPLE_H_
#define LIB_JPEGLI_DOWNSAMPLE_H_

#include "lib/jpegli/common.h"

namespace jpegli {

void ChooseDownsampleMethods(j_compress_ptr cinfo);

void DownsampleInputBuffer(j_compress_ptr cinfo);

void ApplyInputSmoothing(j_compress_ptr cinfo);

}  // namespace jpegli

#endif  // LIB_JPEGLI_DOWNSAMPLE_H_
