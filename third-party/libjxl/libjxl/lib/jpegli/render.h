// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_RENDER_H_
#define LIB_JPEGLI_RENDER_H_

#include <stdint.h>

#include "lib/jpegli/common.h"

namespace jpegli {

void PrepareForOutput(j_decompress_ptr cinfo);

void ProcessOutput(j_decompress_ptr cinfo, size_t* num_output_rows,
                   JSAMPARRAY scanlines, size_t max_output_rows);

void ProcessRawOutput(j_decompress_ptr cinfo, JSAMPIMAGE data);

}  // namespace jpegli

#endif  // LIB_JPEGLI_RENDER_H_
