// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_WASM_DEMO_NO_PNG_H_
#define TOOLS_WASM_DEMO_NO_PNG_H_

#include <stddef.h>
#include <stdint.h>

#include <vector>

extern "C" {

uint8_t* WrapPixelsToPng(size_t width, size_t height, size_t bit_depth,
                         bool has_alpha, const uint8_t* input,
                         const std::vector<uint8_t>& icc,
                         const std::vector<uint8_t>& cicp,
                         uint32_t* output_size);

}  // extern "C"

#endif  // TOOLS_WASM_DEMO_NO_PNG_H_
