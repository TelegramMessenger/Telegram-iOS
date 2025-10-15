// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_ENTROPY_CODING_H_
#define LIB_JPEGLI_ENTROPY_CODING_H_

#include "lib/jpegli/common.h"

namespace jpegli {

size_t MaxNumTokensPerMCURow(j_compress_ptr cinfo);

size_t EstimateNumTokens(j_compress_ptr cinfo, size_t mcu_y, size_t ysize_mcus,
                         size_t num_tokens, size_t max_per_row);

void TokenizeJpeg(j_compress_ptr cinfo);

void CopyHuffmanTables(j_compress_ptr cinfo);

void OptimizeHuffmanCodes(j_compress_ptr cinfo);

void InitEntropyCoder(j_compress_ptr cinfo);

}  // namespace jpegli

#endif  // LIB_JPEGLI_ENTROPY_CODING_H_
