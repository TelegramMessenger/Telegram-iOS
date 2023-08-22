// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Program to test that we can link against the public API of libjpegxl from C.
// This links against the shared libjpegxl library which doesn't expose any of
// the internals of the jxl namespace.

#include <jxl/decode.h>

int main(void) {
  if (!JxlDecoderVersion()) return 1;
  JxlDecoder* dec = JxlDecoderCreate(NULL);
  if (!dec) return 1;
  JxlDecoderDestroy(dec);
}
