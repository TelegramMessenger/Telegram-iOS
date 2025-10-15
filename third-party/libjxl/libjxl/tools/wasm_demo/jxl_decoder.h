// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_WASM_DEMO_JXL_DECODER_H_
#define TOOLS_WASM_DEMO_JXL_DECODER_H_

#include <stddef.h>
#include <stdint.h>

extern "C" {

typedef struct DecoderInstance {
  uint32_t width = 0;
  uint32_t height = 0;
  uint8_t* pixels = nullptr;

  // The rest is opaque.
} DecoderInstance;

/*
  Returns (as uint32_t):
    0 - OOM
    1 - JxlDecoderSetParallelRunner failed
    2 - JxlDecoderSubscribeEvents failed
    3 - JxlDecoderSetProgressiveDetail failed
    >=4 - OK
 */
DecoderInstance* jxlCreateInstance(bool want_sdr, uint32_t display_nits);

void jxlDestroyInstance(DecoderInstance* instance);

/*
  Returns (as uint32_t):
    0 - OK (pixels are ready)
    1 - ready to flush
    2 - needs more input
    >=3 - error
 */
uint32_t jxlProcessInput(DecoderInstance* instance, const uint8_t* input,
                         size_t input_size);

uint32_t jxlFlush(DecoderInstance* instance);

}  // extern "C"

#endif  // TOOLS_WASM_DEMO_JXL_DECODER_H_
