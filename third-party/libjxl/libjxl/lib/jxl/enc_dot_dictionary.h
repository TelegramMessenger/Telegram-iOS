// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_DOT_DICTIONARY_H_
#define LIB_JXL_ENC_DOT_DICTIONARY_H_

// Dots are stored in a dictionary to avoid storing similar dots multiple
// times.

#include <stddef.h>

#include <vector>

#include "lib/jxl/base/status.h"
#include "lib/jxl/chroma_from_luma.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/dec_patch_dictionary.h"
#include "lib/jxl/enc_bit_writer.h"
#include "lib/jxl/enc_params.h"
#include "lib/jxl/enc_patch_dictionary.h"
#include "lib/jxl/image.h"

namespace jxl {

std::vector<PatchInfo> FindDotDictionary(const CompressParams& cparams,
                                         const Image3F& opsin,
                                         const ColorCorrelationMap& cmap,
                                         ThreadPool* pool);

}  // namespace jxl

#endif  // LIB_JXL_ENC_DOT_DICTIONARY_H_
