// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_ADAPTIVE_QUANTIZATION_H_
#define LIB_JPEGLI_ADAPTIVE_QUANTIZATION_H_

#include "lib/jpegli/common.h"

namespace jpegli {

void ComputeAdaptiveQuantField(j_compress_ptr cinfo);

}  // namespace jpegli

#endif  // LIB_JPEGLI_ADAPTIVE_QUANTIZATION_H_
