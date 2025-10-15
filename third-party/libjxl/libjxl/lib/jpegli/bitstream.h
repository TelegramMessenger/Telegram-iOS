// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_BITSTREAM_H_
#define LIB_JPEGLI_BITSTREAM_H_

#include <initializer_list>
#include <vector>

#include "lib/jpegli/encode_internal.h"

namespace jpegli {

void WriteOutput(j_compress_ptr cinfo, const uint8_t* buf, size_t bufsize);
void WriteOutput(j_compress_ptr cinfo, const std::vector<uint8_t>& bytes);
void WriteOutput(j_compress_ptr cinfo, std::initializer_list<uint8_t> bytes);

void EncodeAPP0(j_compress_ptr cinfo);
void EncodeAPP14(j_compress_ptr cinfo);
void WriteFileHeader(j_compress_ptr cinfo);

// Returns true of only baseline 8-bit tables are used.
bool EncodeDQT(j_compress_ptr cinfo, bool write_all_tables);
void EncodeSOF(j_compress_ptr cinfo, bool is_baseline);
void WriteFrameHeader(j_compress_ptr cinfo);

void EncodeDRI(j_compress_ptr cinfo);
void EncodeDHT(j_compress_ptr cinfo, size_t offset, size_t num);
void EncodeSOS(j_compress_ptr cinfo, int scan_index);
void WriteScanHeader(j_compress_ptr cinfo, int scan_index);

void WriteBlock(const int32_t* JXL_RESTRICT symbols,
                const int32_t* JXL_RESTRICT extra_bits, const int num_nonzeros,
                const bool emit_eob,
                const HuffmanCodeTable* JXL_RESTRICT dc_code,
                const HuffmanCodeTable* JXL_RESTRICT ac_code,
                JpegBitWriter* JXL_RESTRICT bw);
void WriteScanData(j_compress_ptr cinfo, int scan_index);

}  // namespace jpegli

#endif  // LIB_JPEGLI_BITSTREAM_H_
