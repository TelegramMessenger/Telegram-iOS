// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/bit_writer.h"

#include "lib/jpegli/encode_internal.h"

namespace jpegli {

void JpegBitWriterInit(j_compress_ptr cinfo) {
  jpeg_comp_master* m = cinfo->master;
  JpegBitWriter* bw = &m->bw;
  size_t buffer_size = m->blocks_per_iMCU_row * (DCTSIZE2 * 16 + 8) + (1 << 16);
  bw->cinfo = cinfo;
  bw->data = Allocate<uint8_t>(cinfo, buffer_size, JPOOL_IMAGE);
  bw->len = buffer_size;
  bw->pos = 0;
  bw->output_pos = 0;
  bw->put_buffer = 0;
  bw->free_bits = 64;
  bw->healthy = true;
}

bool EmptyBitWriterBuffer(JpegBitWriter* bw) {
  while (bw->output_pos < bw->pos) {
    j_compress_ptr cinfo = bw->cinfo;
    if (cinfo->dest->free_in_buffer == 0 &&
        !(*cinfo->dest->empty_output_buffer)(cinfo)) {
      return false;
    }
    size_t buflen = bw->pos - bw->output_pos;
    size_t copylen = std::min<size_t>(cinfo->dest->free_in_buffer, buflen);
    memcpy(cinfo->dest->next_output_byte, bw->data + bw->output_pos, copylen);
    bw->output_pos += copylen;
    cinfo->dest->free_in_buffer -= copylen;
    cinfo->dest->next_output_byte += copylen;
  }
  bw->output_pos = bw->pos = 0;
  return true;
}

void JumpToByteBoundary(JpegBitWriter* bw) {
  size_t n_bits = bw->free_bits & 7u;
  if (n_bits > 0) {
    WriteBits(bw, n_bits, (1u << n_bits) - 1);
  }
  bw->put_buffer <<= bw->free_bits;
  while (bw->free_bits <= 56) {
    int c = (bw->put_buffer >> 56) & 0xFF;
    EmitByte(bw, c);
    bw->put_buffer <<= 8;
    bw->free_bits += 8;
  }
  bw->put_buffer = 0;
  bw->free_bits = 64;
}

}  // namespace jpegli
