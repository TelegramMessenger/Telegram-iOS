// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_DECODE_SCAN_H_
#define LIB_JPEGLI_DECODE_SCAN_H_

#include <stdint.h>

#include "lib/jpegli/common.h"

namespace jpegli {

// Reads the available input in the source manager's input buffer until the end
// of the next iMCU row.
// The corresponding fields of cinfo are updated with the processed input data.
// Upon return, the input buffer will be at the start of an MCU, or at the end
// of the scan.
// Return value is one of:
//   * JPEG_SUSPENDED, if the input buffer ends before the end of an iMCU row;
//   * JPEG_ROW_COMPLETED, if the next iMCU row (but not the scan) is reached;
//   * JPEG_SCAN_COMPLETED, if the end of the scan is reached.
int ProcessScan(j_decompress_ptr cinfo, const uint8_t* const data,
                const size_t len, size_t* pos, size_t* bit_pos);

void PrepareForiMCURow(j_decompress_ptr cinfo);

}  // namespace jpegli

#endif  // LIB_JPEGLI_DECODE_SCAN_H_
