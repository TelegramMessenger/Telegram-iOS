// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_WASM_DEMO_JXL_DECOMPRESSOR_H_
#define TOOLS_WASM_DEMO_JXL_DECOMPRESSOR_H_

#include <stddef.h>
#include <stdint.h>

extern "C" {

typedef struct DecompressorOutput {
  uint32_t size = 0;
  uint8_t* data = nullptr;

  // The rest is opaque.
} DecompressorOutput;

/*
  Returns (as uint32_t):
    0 - OOM
    1 - decoding JXL failed
    2 - encoding PNG failed
    >=4 - OK
 */
DecompressorOutput* jxlDecompress(const uint8_t* input, size_t input_size);

void jxlCleanup(DecompressorOutput* output);

}  // extern "C"

#endif  // TOOLS_WASM_DEMO_JXL_DECOMPRESSOR_H_
