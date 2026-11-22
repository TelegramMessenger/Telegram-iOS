// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_CONTEXT_MAP_H_
#define LIB_JXL_ENC_CONTEXT_MAP_H_

#include <stddef.h>
#include <stdint.h>

#include <vector>

#include "lib/jxl/ac_context.h"
#include "lib/jxl/enc_bit_writer.h"

namespace jxl {

struct AuxOut;

// Max limit is 255 because encoding assumes numbers < 255
// More clusters can help compression, but makes encode/decode somewhat slower
static const size_t kClustersLimit = 128;

// Encodes the given context map to the bit stream. The number of different
// histogram ids is given by num_histograms.
void EncodeContextMap(const std::vector<uint8_t>& context_map,
                      size_t num_histograms, BitWriter* writer, size_t layer,
                      AuxOut* aux_out);

void EncodeBlockCtxMap(const BlockCtxMap& block_ctx_map, BitWriter* writer,
                       AuxOut* aux_out);
}  // namespace jxl

#endif  // LIB_JXL_ENC_CONTEXT_MAP_H_
