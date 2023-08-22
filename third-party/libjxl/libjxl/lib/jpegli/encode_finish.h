// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_ENCODE_FINISH_H_
#define LIB_JPEGLI_ENCODE_FINISH_H_

#include "lib/jpegli/encode_internal.h"

namespace jpegli {

void QuantizetoPSNR(j_compress_ptr cinfo);

}  // namespace jpegli

#endif  // LIB_JPEGLI_ENCODE_FINISH_H_
