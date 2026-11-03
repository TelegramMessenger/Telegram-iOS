// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_DECODE_MARKER_H_
#define LIB_JPEGLI_DECODE_MARKER_H_

#include <stdint.h>

#include "lib/jpegli/common.h"

namespace jpegli {

// Reads the available input in the source manager's input buffer until either
// the end of the next SOS marker or the end of the input.
// The corresponding fields of cinfo are updated with the processed input data.
// Upon return, the input buffer will be at the start or at the end of a marker
// data segment (inter-marker data is allowed).
// Return value is one of:
//   * JPEG_SUSPENDED, if the current input buffer ends before the next SOS or
//       EOI marker. Input buffer refill is handled by the caller;
//   * JPEG_REACHED_SOS, if the next SOS marker is found;
//   * JPEG_REACHED_EOR, if the end of the input is found.
int ProcessMarkers(j_decompress_ptr cinfo, const uint8_t* const data,
                   const size_t len, size_t* pos);

jpeg_marker_parser_method GetMarkerProcessor(j_decompress_ptr cinfo);

}  // namespace jpegli

#endif  // LIB_JPEGLI_DECODE_MARKER_H_
