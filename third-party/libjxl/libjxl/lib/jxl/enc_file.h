// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_FILE_H_
#define LIB_JXL_ENC_FILE_H_

// Facade for JXL encoding.

#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/enc_cache.h"
#include "lib/jxl/enc_params.h"

namespace jxl {

struct AuxOut;
class CodecInOut;

// Compresses pixels from `io` (given in any ColorEncoding).
// `io->metadata.m.original` must be set.
Status EncodeFile(const CompressParams& params, const CodecInOut* io,
                  PassesEncoderState* passes_enc_state, PaddedBytes* compressed,
                  const JxlCmsInterface& cms, AuxOut* aux_out = nullptr,
                  ThreadPool* pool = nullptr);

}  // namespace jxl

#endif  // LIB_JXL_ENC_FILE_H_
