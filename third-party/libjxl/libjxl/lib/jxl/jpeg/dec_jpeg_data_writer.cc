// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/jpeg/dec_jpeg_data_writer.h"

#include <stdlib.h>
#include <string.h> /* for memset, memcpy */

#include <deque>
#include <string>
#include <vector>

#include "lib/jxl/base/bits.h"
#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/common.h"
#include "lib/jxl/image_bundle.h"
#include "lib/jxl/jpeg/dec_jpeg_serialization_state.h"
#include "lib/jxl/jpeg/jpeg_data.h"

namespace jxl {
namespace jpeg {

namespace {

enum struct SerializationStatus {
  NEEDS_MORE_INPUT,
  NEEDS_MORE_OUTPUT,
  ERROR,
  DONE
};

const int kJpegPrecision = 8;

// JpegBitWriter: buffer size
const size_t kJpegBitWriterChunkSize = 16384;

// DCTCodingState: maximum number of correction bits to buffer
const int kJPEGMaxCorrectionBits = 1u << 16;

// Returns non-zero if and only if x has a zero byte, i.e. one of
// x & 0xff, x & 0xff00, ..., x & 0xff00000000000000 is zero.
static JXL_INLINE uint64_t HasZeroByte(uint64_t x) {
  return (x - 0x0101010101010101ULL) & ~x & 0x8080808080808080ULL;
}

void JpegBitWriterInit(JpegBitWriter* bw,
                       std::deque<OutputChunk>* output_queue) {
  bw->output = output_queue;
  bw->chunk = OutputChunk(kJpegBitWriterChunkSize);
  bw->pos = 0;
  bw->put_buffer = 0;
  bw->put_bits = 64;
  bw->healthy = true;
  bw->data = bw->chunk.buffer->data();
}

static JXL_NOINLINE void SwapBuffer(JpegBitWriter* bw) {
  bw->chunk.len = bw->pos;
  bw->output->emplace_back(std::move(bw->chunk));
  bw->chunk = OutputChunk(kJpegBitWriterChunkSize);
  bw->data = bw->chunk.buffer->data();
  bw->pos = 0;
}

static JXL_INLINE void Reserve(JpegBitWriter* bw, size_t n_bytes) {
  if (JXL_UNLIKELY((bw->pos + n_bytes) > kJpegBitWriterChunkSize)) {
    SwapBuffer(bw);
  }
}

/**
 * Writes the given byte to the output, writes an extra zero if byte is 0xFF.
 *
 * This method is "careless" - caller must make sure that there is enough
 * space in the output buffer. Emits up to 2 bytes to buffer.
 */
static JXL_INLINE void EmitByte(JpegBitWriter* bw, int byte) {
  bw->data[bw->pos] = byte;
  bw->data[bw->pos + 1] = 0;
  bw->pos += (byte != 0xFF ? 1 : 2);
}

static JXL_INLINE void DischargeBitBuffer(JpegBitWriter* bw, int nbits,
                                          uint64_t bits) {
  // At this point we are ready to emit the put_buffer to the output.
  // The JPEG format requires that after every 0xff byte in the entropy
  // coded section, there is a zero byte, therefore we first check if any of
  // the 8 bytes of put_buffer is 0xFF.
  bw->put_buffer |= (bits >> -bw->put_bits);
  if (JXL_UNLIKELY(HasZeroByte(~bw->put_buffer))) {
    // We have a 0xFF byte somewhere, examine each byte and append a zero
    // byte if necessary.
    EmitByte(bw, (bw->put_buffer >> 56) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 48) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 40) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 32) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 24) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 16) & 0xFF);
    EmitByte(bw, (bw->put_buffer >> 8) & 0xFF);
    EmitByte(bw, (bw->put_buffer) & 0xFF);
  } else {
    // We don't have any 0xFF bytes, output all 8 bytes without checking.
    StoreBE64(bw->put_buffer, bw->data + bw->pos);
    bw->pos += 8;
  }

  bw->put_bits += 64;
  bw->put_buffer = bits << bw->put_bits;
}

static JXL_INLINE void WriteBits(JpegBitWriter* bw, int nbits, uint64_t bits) {
  JXL_DASSERT(nbits > 0);
  bw->put_bits -= nbits;
  if (JXL_UNLIKELY(bw->put_bits < 0)) {
    if (JXL_UNLIKELY(nbits > 64)) {
      bw->put_bits += nbits;
      bw->healthy = false;
    } else {
      DischargeBitBuffer(bw, nbits, bits);
    }
  } else {
    bw->put_buffer |= (bits << bw->put_bits);
  }
}

void EmitMarker(JpegBitWriter* bw, int marker) {
  Reserve(bw, 2);
  JXL_DASSERT(marker != 0xFF);
  bw->data[bw->pos++] = 0xFF;
  bw->data[bw->pos++] = marker;
}

bool JumpToByteBoundary(JpegBitWriter* bw, const uint8_t** pad_bits,
                        const uint8_t* pad_bits_end) {
  size_t n_bits = bw->put_bits & 7u;
  uint8_t pad_pattern;
  if (*pad_bits == nullptr) {
    pad_pattern = (1u << n_bits) - 1;
  } else {
    pad_pattern = 0;
    const uint8_t* src = *pad_bits;
    // TODO(eustas): bitwise reading looks insanely ineffective...
    while (n_bits--) {
      pad_pattern <<= 1;
      if (src >= pad_bits_end) return false;
      // TODO(eustas): DCHECK *src == {0, 1}
      pad_pattern |= !!*(src++);
    }
    *pad_bits = src;
  }

  Reserve(bw, 16);

  while (bw->put_bits <= 56) {
    int c = (bw->put_buffer >> 56) & 0xFF;
    EmitByte(bw, c);
    bw->put_buffer <<= 8;
    bw->put_bits += 8;
  }
  if (bw->put_bits < 64) {
    int pad_mask = 0xFFu >> (64 - bw->put_bits);
    int c = ((bw->put_buffer >> 56) & ~pad_mask) | pad_pattern;
    EmitByte(bw, c);
  }
  bw->put_buffer = 0;
  bw->put_bits = 64;

  return true;
}

void JpegBitWriterFinish(JpegBitWriter* bw) {
  if (bw->pos == 0) return;
  bw->chunk.len = bw->pos;
  bw->output->emplace_back(std::move(bw->chunk));
  bw->chunk = OutputChunk(nullptr, 0);
  bw->data = nullptr;
  bw->pos = 0;
}

void DCTCodingStateInit(DCTCodingState* s) {
  s->eob_run_ = 0;
  s->cur_ac_huff_ = nullptr;
  s->refinement_bits_.clear();
  s->refinement_bits_.reserve(kJPEGMaxCorrectionBits);
}

static JXL_INLINE void WriteSymbol(int symbol, HuffmanCodeTable* table,
                                   JpegBitWriter* bw) {
  WriteBits(bw, table->depth[symbol], table->code[symbol]);
}

static JXL_INLINE void WriteSymbolBits(int symbol, HuffmanCodeTable* table,
                                       JpegBitWriter* bw, int nbits,
                                       uint64_t bits) {
  WriteBits(bw, nbits + table->depth[symbol],
            bits | (table->code[symbol] << nbits));
}

// Emit all buffered data to the bit stream using the given Huffman code and
// bit writer.
static JXL_INLINE void Flush(DCTCodingState* s, JpegBitWriter* bw) {
  if (s->eob_run_ > 0) {
    int nbits = FloorLog2Nonzero<uint32_t>(s->eob_run_);
    int symbol = nbits << 4u;
    WriteSymbol(symbol, s->cur_ac_huff_, bw);
    if (nbits > 0) {
      WriteBits(bw, nbits, s->eob_run_ & ((1 << nbits) - 1));
    }
    s->eob_run_ = 0;
  }
  for (size_t i = 0; i < s->refinement_bits_.size(); ++i) {
    WriteBits(bw, 1, s->refinement_bits_[i]);
  }
  s->refinement_bits_.clear();
}

// Buffer some more data at the end-of-band (the last non-zero or newly
// non-zero coefficient within the [Ss, Se] spectral band).
static JXL_INLINE void BufferEndOfBand(DCTCodingState* s,
                                       HuffmanCodeTable* ac_huff,
                                       const std::vector<int>* new_bits,
                                       JpegBitWriter* bw) {
  if (s->eob_run_ == 0) {
    s->cur_ac_huff_ = ac_huff;
  }
  ++s->eob_run_;
  if (new_bits) {
    s->refinement_bits_.insert(s->refinement_bits_.end(), new_bits->begin(),
                               new_bits->end());
  }
  if (s->eob_run_ == 0x7FFF ||
      s->refinement_bits_.size() > kJPEGMaxCorrectionBits - kDCTBlockSize + 1) {
    Flush(s, bw);
  }
}

bool BuildHuffmanCodeTable(const JPEGHuffmanCode& huff,
                           HuffmanCodeTable* table) {
  int huff_code[kJpegHuffmanAlphabetSize];
  // +1 for a sentinel element.
  uint32_t huff_size[kJpegHuffmanAlphabetSize + 1];
  int p = 0;
  for (size_t l = 1; l <= kJpegHuffmanMaxBitLength; ++l) {
    int i = huff.counts[l];
    if (p + i > kJpegHuffmanAlphabetSize + 1) {
      return false;
    }
    while (i--) huff_size[p++] = l;
  }

  if (p == 0) {
    return true;
  }

  // Reuse sentinel element.
  int last_p = p - 1;
  huff_size[last_p] = 0;

  int code = 0;
  uint32_t si = huff_size[0];
  p = 0;
  while (huff_size[p]) {
    while ((huff_size[p]) == si) {
      huff_code[p++] = code;
      code++;
    }
    code <<= 1;
    si++;
  }
  for (p = 0; p < last_p; p++) {
    int i = huff.values[p];
    table->depth[i] = huff_size[p];
    table->code[i] = huff_code[p];
  }
  return true;
}

bool EncodeSOI(SerializationState* state) {
  state->output_queue.push_back(OutputChunk({0xFF, 0xD8}));
  return true;
}

bool EncodeEOI(const JPEGData& jpg, SerializationState* state) {
  state->output_queue.push_back(OutputChunk({0xFF, 0xD9}));
  state->output_queue.emplace_back(jpg.tail_data);
  return true;
}

bool EncodeSOF(const JPEGData& jpg, uint8_t marker, SerializationState* state) {
  if (marker <= 0xC2) state->is_progressive = (marker == 0xC2);

  const size_t n_comps = jpg.components.size();
  const size_t marker_len = 8 + 3 * n_comps;
  state->output_queue.emplace_back(marker_len + 2);
  uint8_t* data = state->output_queue.back().buffer->data();
  size_t pos = 0;
  data[pos++] = 0xFF;
  data[pos++] = marker;
  data[pos++] = marker_len >> 8u;
  data[pos++] = marker_len & 0xFFu;
  data[pos++] = kJpegPrecision;
  data[pos++] = jpg.height >> 8u;
  data[pos++] = jpg.height & 0xFFu;
  data[pos++] = jpg.width >> 8u;
  data[pos++] = jpg.width & 0xFFu;
  data[pos++] = n_comps;
  for (size_t i = 0; i < n_comps; ++i) {
    data[pos++] = jpg.components[i].id;
    data[pos++] = ((jpg.components[i].h_samp_factor << 4u) |
                   (jpg.components[i].v_samp_factor));
    const size_t quant_idx = jpg.components[i].quant_idx;
    if (quant_idx >= jpg.quant.size()) return false;
    data[pos++] = jpg.quant[quant_idx].index;
  }
  return true;
}

bool EncodeSOS(const JPEGData& jpg, const JPEGScanInfo& scan_info,
               SerializationState* state) {
  const size_t n_scans = scan_info.num_components;
  const size_t marker_len = 6 + 2 * n_scans;
  state->output_queue.emplace_back(marker_len + 2);
  uint8_t* data = state->output_queue.back().buffer->data();
  size_t pos = 0;
  data[pos++] = 0xFF;
  data[pos++] = 0xDA;
  data[pos++] = marker_len >> 8u;
  data[pos++] = marker_len & 0xFFu;
  data[pos++] = n_scans;
  for (size_t i = 0; i < n_scans; ++i) {
    const JPEGComponentScanInfo& si = scan_info.components[i];
    if (si.comp_idx >= jpg.components.size()) return false;
    data[pos++] = jpg.components[si.comp_idx].id;
    data[pos++] = (si.dc_tbl_idx << 4u) + si.ac_tbl_idx;
  }
  data[pos++] = scan_info.Ss;
  data[pos++] = scan_info.Se;
  data[pos++] = ((scan_info.Ah << 4u) | (scan_info.Al));
  return true;
}

bool EncodeDHT(const JPEGData& jpg, SerializationState* state) {
  const std::vector<JPEGHuffmanCode>& huffman_code = jpg.huffman_code;

  size_t marker_len = 2;
  for (size_t i = state->dht_index; i < huffman_code.size(); ++i) {
    const JPEGHuffmanCode& huff = huffman_code[i];
    marker_len += kJpegHuffmanMaxBitLength;
    for (size_t j = 0; j < huff.counts.size(); ++j) {
      marker_len += huff.counts[j];
    }
    if (huff.is_last) break;
  }
  state->output_queue.emplace_back(marker_len + 2);
  uint8_t* data = state->output_queue.back().buffer->data();
  size_t pos = 0;
  data[pos++] = 0xFF;
  data[pos++] = 0xC4;
  data[pos++] = marker_len >> 8u;
  data[pos++] = marker_len & 0xFFu;
  while (true) {
    const size_t huffman_code_index = state->dht_index++;
    if (huffman_code_index >= huffman_code.size()) {
      return false;
    }
    const JPEGHuffmanCode& huff = huffman_code[huffman_code_index];
    size_t index = huff.slot_id;
    HuffmanCodeTable* huff_table;
    if (index & 0x10) {
      index -= 0x10;
      huff_table = &state->ac_huff_table[index];
    } else {
      huff_table = &state->dc_huff_table[index];
    }
    // TODO(eustas): cache
    huff_table->InitDepths(127);
    if (!BuildHuffmanCodeTable(huff, huff_table)) {
      return false;
    }
    huff_table->initialized = true;
    size_t total_count = 0;
    size_t max_length = 0;
    for (size_t i = 0; i < huff.counts.size(); ++i) {
      if (huff.counts[i] != 0) {
        max_length = i;
      }
      total_count += huff.counts[i];
    }
    --total_count;
    data[pos++] = huff.slot_id;
    for (size_t i = 1; i <= kJpegHuffmanMaxBitLength; ++i) {
      data[pos++] = (i == max_length ? huff.counts[i] - 1 : huff.counts[i]);
    }
    for (size_t i = 0; i < total_count; ++i) {
      data[pos++] = huff.values[i];
    }
    if (huff.is_last) break;
  }
  return true;
}

bool EncodeDQT(const JPEGData& jpg, SerializationState* state) {
  int marker_len = 2;
  for (size_t i = state->dqt_index; i < jpg.quant.size(); ++i) {
    const JPEGQuantTable& table = jpg.quant[i];
    marker_len += 1 + (table.precision ? 2 : 1) * kDCTBlockSize;
    if (table.is_last) break;
  }
  state->output_queue.emplace_back(marker_len + 2);
  uint8_t* data = state->output_queue.back().buffer->data();
  size_t pos = 0;
  data[pos++] = 0xFF;
  data[pos++] = 0xDB;
  data[pos++] = marker_len >> 8u;
  data[pos++] = marker_len & 0xFFu;
  while (true) {
    const size_t idx = state->dqt_index++;
    if (idx >= jpg.quant.size()) {
      return false;  // corrupt input
    }
    const JPEGQuantTable& table = jpg.quant[idx];
    data[pos++] = (table.precision << 4u) + table.index;
    for (size_t i = 0; i < kDCTBlockSize; ++i) {
      int val_idx = kJPEGNaturalOrder[i];
      int val = table.values[val_idx];
      if (table.precision) {
        data[pos++] = val >> 8u;
      }
      data[pos++] = val & 0xFFu;
    }
    if (table.is_last) break;
  }
  return true;
}

bool EncodeDRI(const JPEGData& jpg, SerializationState* state) {
  state->seen_dri_marker = true;
  OutputChunk dri_marker = {0xFF,
                            0xDD,
                            0,
                            4,
                            static_cast<uint8_t>(jpg.restart_interval >> 8),
                            static_cast<uint8_t>(jpg.restart_interval & 0xFF)};
  state->output_queue.push_back(std::move(dri_marker));
  return true;
}

bool EncodeRestart(uint8_t marker, SerializationState* state) {
  state->output_queue.push_back(OutputChunk({0xFF, marker}));
  return true;
}

bool EncodeAPP(const JPEGData& jpg, uint8_t marker, SerializationState* state) {
  // TODO(eustas): check that marker corresponds to payload?
  (void)marker;

  size_t app_index = state->app_index++;
  if (app_index >= jpg.app_data.size()) return false;
  state->output_queue.push_back(OutputChunk({0xFF}));
  state->output_queue.emplace_back(jpg.app_data[app_index]);
  return true;
}

bool EncodeCOM(const JPEGData& jpg, SerializationState* state) {
  size_t com_index = state->com_index++;
  if (com_index >= jpg.com_data.size()) return false;
  state->output_queue.push_back(OutputChunk({0xFF}));
  state->output_queue.emplace_back(jpg.com_data[com_index]);
  return true;
}

bool EncodeInterMarkerData(const JPEGData& jpg, SerializationState* state) {
  size_t index = state->data_index++;
  if (index >= jpg.inter_marker_data.size()) return false;
  state->output_queue.emplace_back(jpg.inter_marker_data[index]);
  return true;
}

bool EncodeDCTBlockSequential(const coeff_t* coeffs, HuffmanCodeTable* dc_huff,
                              HuffmanCodeTable* ac_huff, int num_zero_runs,
                              coeff_t* last_dc_coeff, JpegBitWriter* bw) {
  coeff_t temp2;
  coeff_t temp;
  coeff_t litmus = 0;
  temp2 = coeffs[0];
  temp = temp2 - *last_dc_coeff;
  *last_dc_coeff = temp2;
  temp2 = temp >> (8 * sizeof(coeff_t) - 1);
  temp += temp2;
  temp2 ^= temp;

  int dc_nbits = (temp2 == 0) ? 0 : (FloorLog2Nonzero<uint32_t>(temp2) + 1);
  WriteSymbol(dc_nbits, dc_huff, bw);
#if false
  // If the input is corrupt, this could be triggered. Checking is
  // costly though, so it makes more sense to avoid this branch.
  // (producing a corrupt JPEG when the input is corrupt, instead
  // of catching it and returning error)
  if (dc_nbits >= 12) return false;
#endif
  if (dc_nbits) {
    WriteBits(bw, dc_nbits, temp & ((1u << dc_nbits) - 1));
  }
  int16_t r = 0;

  for (size_t i = 1; i < 64; i++) {
    if ((temp = coeffs[kJPEGNaturalOrder[i]]) == 0) {
      r++;
    } else {
      temp2 = temp >> (8 * sizeof(coeff_t) - 1);
      temp += temp2;
      temp2 ^= temp;
      if (JXL_UNLIKELY(r > 15)) {
        WriteSymbol(0xf0, ac_huff, bw);
        r -= 16;
        if (r > 15) {
          WriteSymbol(0xf0, ac_huff, bw);
          r -= 16;
        }
        if (r > 15) {
          WriteSymbol(0xf0, ac_huff, bw);
          r -= 16;
        }
      }
      litmus |= temp2;
      int ac_nbits =
          FloorLog2Nonzero<uint32_t>(static_cast<uint16_t>(temp2)) + 1;
      int symbol = (r << 4u) + ac_nbits;
      WriteSymbolBits(symbol, ac_huff, bw, ac_nbits,
                      temp & ((1 << ac_nbits) - 1));
      r = 0;
    }
  }

  for (int i = 0; i < num_zero_runs; ++i) {
    WriteSymbol(0xf0, ac_huff, bw);
    r -= 16;
  }
  if (r > 0) {
    WriteSymbol(0, ac_huff, bw);
  }
  return (litmus >= 0);
}

bool EncodeDCTBlockProgressive(const coeff_t* coeffs, HuffmanCodeTable* dc_huff,
                               HuffmanCodeTable* ac_huff, int Ss, int Se,
                               int Al, int num_zero_runs,
                               DCTCodingState* coding_state,
                               coeff_t* last_dc_coeff, JpegBitWriter* bw) {
  bool eob_run_allowed = Ss > 0;
  coeff_t temp2;
  coeff_t temp;
  if (Ss == 0) {
    temp2 = coeffs[0] >> Al;
    temp = temp2 - *last_dc_coeff;
    *last_dc_coeff = temp2;
    temp2 = temp;
    if (temp < 0) {
      temp = -temp;
      if (temp < 0) return false;
      temp2--;
    }
    int nbits = (temp == 0) ? 0 : (FloorLog2Nonzero<uint32_t>(temp) + 1);
    WriteSymbol(nbits, dc_huff, bw);
    if (nbits) {
      WriteBits(bw, nbits, temp2 & ((1 << nbits) - 1));
    }
    ++Ss;
  }
  if (Ss > Se) {
    return true;
  }
  int r = 0;
  for (int k = Ss; k <= Se; ++k) {
    if ((temp = coeffs[kJPEGNaturalOrder[k]]) == 0) {
      r++;
      continue;
    }
    if (temp < 0) {
      temp = -temp;
      if (temp < 0) return false;
      temp >>= Al;
      temp2 = ~temp;
    } else {
      temp >>= Al;
      temp2 = temp;
    }
    if (temp == 0) {
      r++;
      continue;
    }
    Flush(coding_state, bw);
    while (r > 15) {
      WriteSymbol(0xf0, ac_huff, bw);
      r -= 16;
    }
    int nbits = FloorLog2Nonzero<uint32_t>(temp) + 1;
    int symbol = (r << 4u) + nbits;
    WriteSymbol(symbol, ac_huff, bw);
    WriteBits(bw, nbits, temp2 & ((1 << nbits) - 1));
    r = 0;
  }
  if (num_zero_runs > 0) {
    Flush(coding_state, bw);
    for (int i = 0; i < num_zero_runs; ++i) {
      WriteSymbol(0xf0, ac_huff, bw);
      r -= 16;
    }
  }
  if (r > 0) {
    BufferEndOfBand(coding_state, ac_huff, nullptr, bw);
    if (!eob_run_allowed) {
      Flush(coding_state, bw);
    }
  }
  return true;
}

bool EncodeRefinementBits(const coeff_t* coeffs, HuffmanCodeTable* ac_huff,
                          int Ss, int Se, int Al, DCTCodingState* coding_state,
                          JpegBitWriter* bw) {
  bool eob_run_allowed = Ss > 0;
  if (Ss == 0) {
    // Emit next bit of DC component.
    WriteBits(bw, 1, (coeffs[0] >> Al) & 1);
    ++Ss;
  }
  if (Ss > Se) {
    return true;
  }
  int abs_values[kDCTBlockSize];
  int eob = 0;
  for (int k = Ss; k <= Se; k++) {
    const coeff_t abs_val = std::abs(coeffs[kJPEGNaturalOrder[k]]);
    abs_values[k] = abs_val >> Al;
    if (abs_values[k] == 1) {
      eob = k;
    }
  }
  int r = 0;
  std::vector<int> refinement_bits;
  refinement_bits.reserve(kDCTBlockSize);
  for (int k = Ss; k <= Se; k++) {
    if (abs_values[k] == 0) {
      r++;
      continue;
    }
    while (r > 15 && k <= eob) {
      Flush(coding_state, bw);
      WriteSymbol(0xf0, ac_huff, bw);
      r -= 16;
      for (int bit : refinement_bits) {
        WriteBits(bw, 1, bit);
      }
      refinement_bits.clear();
    }
    if (abs_values[k] > 1) {
      refinement_bits.push_back(abs_values[k] & 1u);
      continue;
    }
    Flush(coding_state, bw);
    int symbol = (r << 4u) + 1;
    int new_non_zero_bit = (coeffs[kJPEGNaturalOrder[k]] < 0) ? 0 : 1;
    WriteSymbol(symbol, ac_huff, bw);
    WriteBits(bw, 1, new_non_zero_bit);
    for (int bit : refinement_bits) {
      WriteBits(bw, 1, bit);
    }
    refinement_bits.clear();
    r = 0;
  }
  if (r > 0 || !refinement_bits.empty()) {
    BufferEndOfBand(coding_state, ac_huff, &refinement_bits, bw);
    if (!eob_run_allowed) {
      Flush(coding_state, bw);
    }
  }
  return true;
}

size_t NumHistograms(const JPEGData& jpg) {
  size_t num = 0;
  for (const auto& si : jpg.scan_info) {
    num += si.num_components;
  }
  return num;
}

size_t HistogramIndex(const JPEGData& jpg, size_t scan_index,
                      size_t component_index) {
  size_t idx = 0;
  for (size_t i = 0; i < scan_index; ++i) {
    idx += jpg.scan_info[i].num_components;
  }
  return idx + component_index;
}

template <int kMode>
SerializationStatus JXL_NOINLINE DoEncodeScan(const JPEGData& jpg,
                                              SerializationState* state) {
  const JPEGScanInfo& scan_info = jpg.scan_info[state->scan_index];
  EncodeScanState& ss = state->scan_state;

  const int restart_interval =
      state->seen_dri_marker ? jpg.restart_interval : 0;

  const auto get_next_extra_zero_run_index = [&ss, &scan_info]() -> int {
    if (ss.extra_zero_runs_pos < scan_info.extra_zero_runs.size()) {
      return scan_info.extra_zero_runs[ss.extra_zero_runs_pos].block_idx;
    } else {
      return -1;
    }
  };

  const auto get_next_reset_point = [&ss, &scan_info]() -> int {
    if (ss.next_reset_point_pos < scan_info.reset_points.size()) {
      return scan_info.reset_points[ss.next_reset_point_pos++];
    } else {
      return -1;
    }
  };

  if (ss.stage == EncodeScanState::HEAD) {
    if (!EncodeSOS(jpg, scan_info, state)) return SerializationStatus::ERROR;
    JpegBitWriterInit(&ss.bw, &state->output_queue);
    DCTCodingStateInit(&ss.coding_state);
    ss.restarts_to_go = restart_interval;
    ss.next_restart_marker = 0;
    ss.block_scan_index = 0;
    ss.extra_zero_runs_pos = 0;
    ss.next_extra_zero_run_index = get_next_extra_zero_run_index();
    ss.next_reset_point_pos = 0;
    ss.next_reset_point = get_next_reset_point();
    ss.mcu_y = 0;
    memset(ss.last_dc_coeff, 0, sizeof(ss.last_dc_coeff));
    ss.stage = EncodeScanState::BODY;
  }
  JpegBitWriter* bw = &ss.bw;
  DCTCodingState* coding_state = &ss.coding_state;

  JXL_DASSERT(ss.stage == EncodeScanState::BODY);

  // "Non-interleaved" means color data comes in separate scans, in other words
  // each scan can contain only one color component.
  const bool is_interleaved = (scan_info.num_components > 1);
  int MCUs_per_row = 0;
  int MCU_rows = 0;
  jpg.CalculateMcuSize(scan_info, &MCUs_per_row, &MCU_rows);
  const bool is_progressive = state->is_progressive;
  const int Al = is_progressive ? scan_info.Al : 0;
  const int Ss = is_progressive ? scan_info.Ss : 0;
  const int Se = is_progressive ? scan_info.Se : 63;

  // DC-only is defined by [0..0] spectral range.
  const bool want_ac = ((Ss != 0) || (Se != 0));
  const bool want_dc = (Ss == 0);
  // TODO: support streaming decoding again.
  const bool complete_ac = true;
  const bool has_ac = true;
  if (want_ac && !has_ac) return SerializationStatus::NEEDS_MORE_INPUT;

  // |has_ac| implies |complete_dc| but not vice versa; for the sake of
  // simplicity we pretend they are equal, because they are separated by just a
  // few bytes of input.
  const bool complete_dc = has_ac;
  const bool complete = want_ac ? complete_ac : complete_dc;
  // When "incomplete" |ac_dc| tracks information about current ("incomplete")
  // band parsing progress.

  // FIXME: Is this always complete?
  // const int last_mcu_y =
  //     complete ? MCU_rows : parsing_state.internal->ac_dc.next_mcu_y *
  //     v_group;
  (void)complete;
  const int last_mcu_y = complete ? MCU_rows : 0;

  for (; ss.mcu_y < last_mcu_y; ++ss.mcu_y) {
    for (int mcu_x = 0; mcu_x < MCUs_per_row; ++mcu_x) {
      // Possibly emit a restart marker.
      if (restart_interval > 0 && ss.restarts_to_go == 0) {
        Flush(coding_state, bw);
        if (!JumpToByteBoundary(bw, &state->pad_bits, state->pad_bits_end)) {
          return SerializationStatus::ERROR;
        }
        EmitMarker(bw, 0xD0 + ss.next_restart_marker);
        ss.next_restart_marker += 1;
        ss.next_restart_marker &= 0x7;
        ss.restarts_to_go = restart_interval;
        memset(ss.last_dc_coeff, 0, sizeof(ss.last_dc_coeff));
      }

      // Encode one MCU
      for (size_t i = 0; i < scan_info.num_components; ++i) {
        const JPEGComponentScanInfo& si = scan_info.components[i];
        const JPEGComponent& c = jpg.components[si.comp_idx];
        size_t dc_tbl_idx = si.dc_tbl_idx;
        size_t ac_tbl_idx = si.ac_tbl_idx;
        HuffmanCodeTable* dc_huff = &state->dc_huff_table[dc_tbl_idx];
        HuffmanCodeTable* ac_huff = &state->ac_huff_table[ac_tbl_idx];
        if (want_dc && !dc_huff->initialized) {
          return SerializationStatus::ERROR;
        }
        if (want_ac && !ac_huff->initialized) {
          return SerializationStatus::ERROR;
        }
        int n_blocks_y = is_interleaved ? c.v_samp_factor : 1;
        int n_blocks_x = is_interleaved ? c.h_samp_factor : 1;
        // compressed size per block cannot be more than 512 bytes per component
        Reserve(bw, 512 * n_blocks_y * n_blocks_x);
        for (int iy = 0; iy < n_blocks_y; ++iy) {
          for (int ix = 0; ix < n_blocks_x; ++ix) {
            int block_y = ss.mcu_y * n_blocks_y + iy;
            int block_x = mcu_x * n_blocks_x + ix;
            int block_idx = block_y * c.width_in_blocks + block_x;
            if (ss.block_scan_index == ss.next_reset_point) {
              Flush(coding_state, bw);
              ss.next_reset_point = get_next_reset_point();
            }
            int num_zero_runs = 0;
            if (ss.block_scan_index == ss.next_extra_zero_run_index) {
              num_zero_runs = scan_info.extra_zero_runs[ss.extra_zero_runs_pos]
                                  .num_extra_zero_runs;
              ++ss.extra_zero_runs_pos;
              ss.next_extra_zero_run_index = get_next_extra_zero_run_index();
            }
            const coeff_t* coeffs = &c.coeffs[block_idx << 6];
            bool ok;
            if (kMode == 0) {
              ok = EncodeDCTBlockSequential(coeffs, dc_huff, ac_huff,
                                            num_zero_runs,
                                            ss.last_dc_coeff + si.comp_idx, bw);
            } else if (kMode == 1) {
              ok = EncodeDCTBlockProgressive(
                  coeffs, dc_huff, ac_huff, Ss, Se, Al, num_zero_runs,
                  coding_state, ss.last_dc_coeff + si.comp_idx, bw);
            } else {
              ok = EncodeRefinementBits(coeffs, ac_huff, Ss, Se, Al,
                                        coding_state, bw);
            }
            if (!ok) return SerializationStatus::ERROR;
            ++ss.block_scan_index;
          }
        }
      }
      --ss.restarts_to_go;
    }
  }
  if (ss.mcu_y < MCU_rows) {
    if (!bw->healthy) return SerializationStatus::ERROR;
    return SerializationStatus::NEEDS_MORE_INPUT;
  }
  Flush(coding_state, bw);
  if (!JumpToByteBoundary(bw, &state->pad_bits, state->pad_bits_end)) {
    return SerializationStatus::ERROR;
  }
  JpegBitWriterFinish(bw);
  ss.stage = EncodeScanState::HEAD;
  state->scan_index++;
  if (!bw->healthy) return SerializationStatus::ERROR;

  return SerializationStatus::DONE;
}

static SerializationStatus JXL_INLINE EncodeScan(const JPEGData& jpg,
                                                 SerializationState* state) {
  const JPEGScanInfo& scan_info = jpg.scan_info[state->scan_index];
  const bool is_progressive = state->is_progressive;
  const int Al = is_progressive ? scan_info.Al : 0;
  const int Ah = is_progressive ? scan_info.Ah : 0;
  const int Ss = is_progressive ? scan_info.Ss : 0;
  const int Se = is_progressive ? scan_info.Se : 63;
  const bool need_sequential =
      !is_progressive || (Ah == 0 && Al == 0 && Ss == 0 && Se == 63);
  if (need_sequential) {
    return DoEncodeScan<0>(jpg, state);
  } else if (Ah == 0) {
    return DoEncodeScan<1>(jpg, state);
  } else {
    return DoEncodeScan<2>(jpg, state);
  }
}

SerializationStatus SerializeSection(uint8_t marker, SerializationState* state,
                                     const JPEGData& jpg) {
  const auto to_status = [](bool result) {
    return result ? SerializationStatus::DONE : SerializationStatus::ERROR;
  };
  // TODO(eustas): add and use marker enum
  switch (marker) {
    case 0xC0:
    case 0xC1:
    case 0xC2:
    case 0xC9:
    case 0xCA:
      return to_status(EncodeSOF(jpg, marker, state));

    case 0xC4:
      return to_status(EncodeDHT(jpg, state));

    case 0xD0:
    case 0xD1:
    case 0xD2:
    case 0xD3:
    case 0xD4:
    case 0xD5:
    case 0xD6:
    case 0xD7:
      return to_status(EncodeRestart(marker, state));

    case 0xD9:
      return to_status(EncodeEOI(jpg, state));

    case 0xDA:
      return EncodeScan(jpg, state);

    case 0xDB:
      return to_status(EncodeDQT(jpg, state));

    case 0xDD:
      return to_status(EncodeDRI(jpg, state));

    case 0xE0:
    case 0xE1:
    case 0xE2:
    case 0xE3:
    case 0xE4:
    case 0xE5:
    case 0xE6:
    case 0xE7:
    case 0xE8:
    case 0xE9:
    case 0xEA:
    case 0xEB:
    case 0xEC:
    case 0xED:
    case 0xEE:
    case 0xEF:
      return to_status(EncodeAPP(jpg, marker, state));

    case 0xFE:
      return to_status(EncodeCOM(jpg, state));

    case 0xFF:
      return to_status(EncodeInterMarkerData(jpg, state));

    default:
      return SerializationStatus::ERROR;
  }
}

// TODO(veluca): add streaming support again.
Status WriteJpegInternal(const JPEGData& jpg, const JPEGOutput& out,
                         SerializationState* ss) {
  const auto maybe_push_output = [&]() -> Status {
    if (ss->stage != SerializationState::STAGE_ERROR) {
      while (!ss->output_queue.empty()) {
        auto& chunk = ss->output_queue.front();
        size_t num_written = out(chunk.next, chunk.len);
        if (num_written == 0 && chunk.len > 0) {
          return StatusMessage(Status(StatusCode::kNotEnoughBytes),
                               "Failed to write output");
        }
        chunk.len -= num_written;
        if (chunk.len == 0) {
          ss->output_queue.pop_front();
        }
      }
    }
    return true;
  };

  while (true) {
    switch (ss->stage) {
      case SerializationState::STAGE_INIT: {
        // Valid Brunsli requires, at least, 0xD9 marker.
        // This might happen on corrupted stream, or on unconditioned JPEGData.
        // TODO(eustas): check D9 in the only one and is the last one.
        if (jpg.marker_order.empty()) {
          ss->stage = SerializationState::STAGE_ERROR;
          break;
        }
        ss->dc_huff_table.resize(kMaxHuffmanTables);
        ss->ac_huff_table.resize(kMaxHuffmanTables);
        if (jpg.has_zero_padding_bit) {
          ss->pad_bits = jpg.padding_bits.data();
          ss->pad_bits_end = ss->pad_bits + jpg.padding_bits.size();
        }

        EncodeSOI(ss);
        JXL_QUIET_RETURN_IF_ERROR(maybe_push_output());
        ss->stage = SerializationState::STAGE_SERIALIZE_SECTION;
        break;
      }

      case SerializationState::STAGE_SERIALIZE_SECTION: {
        if (ss->section_index >= jpg.marker_order.size()) {
          ss->stage = SerializationState::STAGE_DONE;
          break;
        }
        uint8_t marker = jpg.marker_order[ss->section_index];
        SerializationStatus status = SerializeSection(marker, ss, jpg);
        if (status == SerializationStatus::ERROR) {
          JXL_WARNING("Failed to encode marker 0x%.2x", marker);
          ss->stage = SerializationState::STAGE_ERROR;
          break;
        }
        JXL_QUIET_RETURN_IF_ERROR(maybe_push_output());
        if (status == SerializationStatus::NEEDS_MORE_INPUT) {
          return JXL_FAILURE("Incomplete serialization data");
        } else if (status != SerializationStatus::DONE) {
          JXL_DASSERT(false);
          ss->stage = SerializationState::STAGE_ERROR;
          break;
        }
        ++ss->section_index;
        break;
      }

      case SerializationState::STAGE_DONE:
        JXL_ASSERT(ss->output_queue.empty());
        if (ss->pad_bits != nullptr && ss->pad_bits != ss->pad_bits_end) {
          return JXL_FAILURE("Invalid number of padding bits.");
        }
        return true;

      case SerializationState::STAGE_ERROR:
        return JXL_FAILURE("JPEG serialization error");
    }
  }
}

}  // namespace

Status WriteJpeg(const JPEGData& jpg, const JPEGOutput& out) {
  auto ss = jxl::make_unique<SerializationState>();
  return WriteJpegInternal(jpg, out, ss.get());
}

}  // namespace jpeg
}  // namespace jxl
