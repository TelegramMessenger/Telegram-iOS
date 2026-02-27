// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_FIELDS_H_
#define LIB_JXL_ENC_FIELDS_H_

#include "lib/jxl/base/status.h"
#include "lib/jxl/enc_bit_writer.h"
#include "lib/jxl/frame_header.h"
#include "lib/jxl/headers.h"
#include "lib/jxl/image_metadata.h"
#include "lib/jxl/quantizer.h"

namespace jxl {

struct AuxOut;

// Write headers from the CodecMetadata. Also may modify nonserialized_...
// fields of the metadata.
Status WriteCodestreamHeaders(CodecMetadata* metadata, BitWriter* writer,
                              AuxOut* aux_out);

Status WriteFrameHeader(const FrameHeader& frame,
                        BitWriter* JXL_RESTRICT writer, AuxOut* aux_out);

Status WriteQuantizerParams(const QuantizerParams& params,
                            BitWriter* JXL_RESTRICT writer, size_t layer,
                            AuxOut* aux_out);

Status WriteSizeHeader(const SizeHeader& size, BitWriter* JXL_RESTRICT writer,
                       size_t layer, AuxOut* aux_out);

}  // namespace jxl

#endif  // LIB_JXL_ENC_FIELDS_H_
