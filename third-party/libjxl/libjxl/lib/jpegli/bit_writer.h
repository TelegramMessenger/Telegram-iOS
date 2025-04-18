// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JPEGLI_BIT_WRITER_H_
#define LIB_JPEGLI_BIT_WRITER_H_

#include <stdint.h>
#include <string.h>

#include "lib/jpegli/common.h"
#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/compiler_specific.h"

namespace jpegli {

// Handles the packing of bits into output bytes.
struct JpegBitWriter {
  j_compress_ptr cinfo;
  uint8_t* data;
  size_t len;
  size_t pos;
  size_t output_pos;
  uint64_t put_buffer;
  int free_bits;
  bool healthy;
};

void JpegBitWriterInit(j_compress_ptr cinfo);

bool EmptyBitWriterBuffer(JpegBitWriter* bw);

void JumpToByteBoundary(JpegBitWriter* bw);

// Returns non-zero if and only if x has a zero byte, i.e. one of
// x & 0xff, x & 0xff00, ..., x & 0xff00000000000000 is zero.
static JXL_INLINE uint64_t HasZeroByte(uint64_t x) {
  return (x - 0x0101010101010101ULL) & ~x & 0x8080808080808080ULL;
}

/**
 * Writes the given byte to the output, writes an extra zero if byte is 0xFF.
 *
 * This method is "careless" - caller must make sure that there is enough
 * space in the output buffer. Emits up to 2 bytes to buffer.
 */
static JXL_INLINE void EmitByte(JpegBitWriter* bw, int byte) {
  bw->data[bw->pos++] = byte;
  if (byte == 0xFF) bw->data[bw->pos++] = 0;
}

static JXL_INLINE void DischargeBitBuffer(JpegBitWriter* bw) {
  // At this point we are ready to emit the bytes of put_buffer to the output.
  // The JPEG format requires that after every 0xff byte in the entropy
  // coded section, there is a zero byte, therefore we first check if any of
  // the bytes of put_buffer is 0xFF.
  if (HasZeroByte(~bw->put_buffer)) {
    // We have a 0xFF byte somewhere, examine each byte and append a zero
    // byte if necessary.
    EmitByte(bw, (bw->put_buffer >> 56) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 48) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 40) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 32) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 24) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 16) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 8) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 0) & 0xFF);
  } else {
    // We don't have any 0xFF bytes, output all 8 bytes without checking.
    StoreBE64(bw->put_buffer, bw->data + bw->pos);
    bw->pos += 8;
  }
}

static JXL_INLINE void WriteBits(JpegBitWriter* bw, int nbits, uint64_t bits) {
  // This is an optimization; if everything goes well,
  // then |nbits| is positive; if non-existing Huffman symbol is going to be
  // encoded, its length should be zero; later encoder could check the
  // "health" of JpegBitWriter.
  if (nbits == 0) {
    bw->healthy = false;
    return;
  }
  bw->free_bits -= nbits;
  if (bw->free_bits < 0) {
    bw->put_buffer <<= (bw->free_bits + nbits);
    bw->put_buffer |= (bits >> -bw->free_bits);
    DischargeBitBuffer(bw);
    bw->free_bits += 64;
    bw->put_buffer = nbits;
  }
  bw->put_buffer <<= nbits;
  bw->put_buffer |= bits;
}

}  // namespace jpegli
#endif  // LIB_JPEGLI_BIT_WRITER_H_
