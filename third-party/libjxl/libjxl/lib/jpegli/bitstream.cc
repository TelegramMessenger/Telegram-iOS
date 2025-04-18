// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/bitstream.h"

#include <cmath>

#include "lib/jpegli/bit_writer.h"
#include "lib/jpegli/error.h"
#include "lib/jpegli/memory_manager.h"

namespace jpegli {

void WriteOutput(j_compress_ptr cinfo, const uint8_t* buf, size_t bufsize) {
  size_t pos = 0;
  while (pos < bufsize) {
    if (cinfo->dest->free_in_buffer == 0 &&
        !(*cinfo->dest->empty_output_buffer)(cinfo)) {
      JPEGLI_ERROR("Destination suspension is not supported in markers.");
    }
    size_t len = std::min<size_t>(cinfo->dest->free_in_buffer, bufsize - pos);
    memcpy(cinfo->dest->next_output_byte, buf + pos, len);
    pos += len;
    cinfo->dest->free_in_buffer -= len;
    cinfo->dest->next_output_byte += len;
  }
}

void WriteOutput(j_compress_ptr cinfo, const std::vector<uint8_t>& bytes) {
  WriteOutput(cinfo, bytes.data(), bytes.size());
}

void WriteOutput(j_compress_ptr cinfo, std::initializer_list<uint8_t> bytes) {
  WriteOutput(cinfo, bytes.begin(), bytes.size());
}

void EncodeAPP0(j_compress_ptr cinfo) {
  WriteOutput(cinfo,
              {0xff, 0xe0, 0, 16, 'J', 'F', 'I', 'F', '\0',
               cinfo->JFIF_major_version, cinfo->JFIF_minor_version,
               cinfo->density_unit, static_cast<uint8_t>(cinfo->X_density >> 8),
               static_cast<uint8_t>(cinfo->X_density & 0xff),
               static_cast<uint8_t>(cinfo->Y_density >> 8),
               static_cast<uint8_t>(cinfo->Y_density & 0xff), 0, 0});
}

void EncodeAPP14(j_compress_ptr cinfo) {
  uint8_t color_transform = cinfo->jpeg_color_space == JCS_YCbCr  ? 1
                            : cinfo->jpeg_color_space == JCS_YCCK ? 2
                                                                  : 0;
  WriteOutput(cinfo, {0xff, 0xee, 0, 14, 'A', 'd', 'o', 'b', 'e', 0, 100, 0, 0,
                      0, 0, color_transform});
}

void WriteFileHeader(j_compress_ptr cinfo) {
  WriteOutput(cinfo, {0xFF, 0xD8});  // SOI
  if (cinfo->write_JFIF_header) {
    EncodeAPP0(cinfo);
  }
  if (cinfo->write_Adobe_marker) {
    EncodeAPP14(cinfo);
  }
}

bool EncodeDQT(j_compress_ptr cinfo, bool write_all_tables) {
  uint8_t data[4 + NUM_QUANT_TBLS * (1 + 2 * DCTSIZE2)];  // 520 bytes
  size_t pos = 0;
  data[pos++] = 0xFF;
  data[pos++] = 0xDB;
  pos += 2;  // Length will be filled in later.

  int send_table[NUM_QUANT_TBLS] = {};
  if (write_all_tables) {
    for (int i = 0; i < NUM_QUANT_TBLS; ++i) {
      if (cinfo->quant_tbl_ptrs[i]) send_table[i] = 1;
    }
  } else {
    for (int c = 0; c < cinfo->num_components; ++c) {
      send_table[cinfo->comp_info[c].quant_tbl_no] = 1;
    }
  }

  bool is_baseline = true;
  for (int i = 0; i < NUM_QUANT_TBLS; ++i) {
    if (!send_table[i]) continue;
    JQUANT_TBL* quant_table = cinfo->quant_tbl_ptrs[i];
    if (quant_table == nullptr) {
      JPEGLI_ERROR("Missing quant table %d", i);
    }
    int precision = 0;
    for (size_t k = 0; k < DCTSIZE2; ++k) {
      if (quant_table->quantval[k] > 255) {
        precision = 1;
        is_baseline = false;
      }
    }
    if (quant_table->sent_table) {
      continue;
    }
    data[pos++] = (precision << 4) + i;
    for (size_t j = 0; j < DCTSIZE2; ++j) {
      int val_idx = kJPEGNaturalOrder[j];
      int val = quant_table->quantval[val_idx];
      if (val == 0) {
        JPEGLI_ERROR("Invalid quantval 0.");
      }
      if (precision) {
        data[pos++] = val >> 8;
      }
      data[pos++] = val & 0xFFu;
    }
    quant_table->sent_table = TRUE;
  }
  if (pos > 4) {
    data[2] = (pos - 2) >> 8u;
    data[3] = (pos - 2) & 0xFFu;
    WriteOutput(cinfo, data, pos);
  }
  return is_baseline;
}

void EncodeSOF(j_compress_ptr cinfo, bool is_baseline) {
  if (cinfo->data_precision != kJpegPrecision) {
    is_baseline = false;
    JPEGLI_ERROR("Unsupported data precision %d", cinfo->data_precision);
  }
  const uint8_t marker = cinfo->progressive_mode ? 0xc2
                         : is_baseline           ? 0xc0
                                                 : 0xc1;
  const size_t n_comps = cinfo->num_components;
  const size_t marker_len = 8 + 3 * n_comps;
  std::vector<uint8_t> data(marker_len + 2);
  size_t pos = 0;
  data[pos++] = 0xFF;
  data[pos++] = marker;
  data[pos++] = marker_len >> 8u;
  data[pos++] = marker_len & 0xFFu;
  data[pos++] = kJpegPrecision;
  data[pos++] = cinfo->image_height >> 8u;
  data[pos++] = cinfo->image_height & 0xFFu;
  data[pos++] = cinfo->image_width >> 8u;
  data[pos++] = cinfo->image_width & 0xFFu;
  data[pos++] = n_comps;
  for (size_t i = 0; i < n_comps; ++i) {
    jpeg_component_info* comp = &cinfo->comp_info[i];
    data[pos++] = comp->component_id;
    data[pos++] = ((comp->h_samp_factor << 4u) | (comp->v_samp_factor));
    const uint32_t quant_idx = comp->quant_tbl_no;
    if (cinfo->quant_tbl_ptrs[quant_idx] == nullptr) {
      JPEGLI_ERROR("Invalid component quant table index %u.", quant_idx);
    }
    data[pos++] = quant_idx;
  }
  WriteOutput(cinfo, data);
}

void WriteFrameHeader(j_compress_ptr cinfo) {
  jpeg_comp_master* m = cinfo->master;
  bool is_baseline = EncodeDQT(cinfo, /*write_all_tables=*/false);
  if (cinfo->progressive_mode || cinfo->arith_code ||
      cinfo->data_precision != 8) {
    is_baseline = false;
  }
  for (size_t i = 0; i < m->num_huffman_tables; ++i) {
    int slot_id = m->slot_id_map[i];
    if (slot_id > 0x11 || (slot_id > 0x01 && slot_id < 0x10)) {
      is_baseline = false;
    }
  }
  EncodeSOF(cinfo, is_baseline);
}

void EncodeDRI(j_compress_ptr cinfo) {
  WriteOutput(cinfo, {0xFF, 0xDD, 0, 4,
                      static_cast<uint8_t>(cinfo->restart_interval >> 8),
                      static_cast<uint8_t>(cinfo->restart_interval & 0xFF)});
}

void EncodeDHT(j_compress_ptr cinfo, size_t offset, size_t num) {
  jpeg_comp_master* m = cinfo->master;
  size_t marker_len = 2;
  for (size_t i = 0; i < num; ++i) {
    const JHUFF_TBL& table = m->huffman_tables[offset + i];
    if (table.sent_table) continue;
    marker_len += kJpegHuffmanMaxBitLength + 1;
    for (size_t j = 0; j <= kJpegHuffmanMaxBitLength; ++j) {
      marker_len += table.bits[j];
    }
  }
  std::vector<uint8_t> data(marker_len + 2);
  size_t pos = 0;
  data[pos++] = 0xFF;
  data[pos++] = 0xC4;
  data[pos++] = marker_len >> 8u;
  data[pos++] = marker_len & 0xFFu;
  for (size_t i = 0; i < num; ++i) {
    const JHUFF_TBL& table = m->huffman_tables[offset + i];
    if (table.sent_table) continue;
    size_t total_count = 0;
    for (size_t i = 0; i <= kJpegHuffmanMaxBitLength; ++i) {
      total_count += table.bits[i];
    }
    data[pos++] = m->slot_id_map[offset + i];
    for (size_t i = 1; i <= kJpegHuffmanMaxBitLength; ++i) {
      data[pos++] = table.bits[i];
    }
    for (size_t i = 0; i < total_count; ++i) {
      data[pos++] = table.huffval[i];
    }
  }
  if (marker_len > 2) {
    WriteOutput(cinfo, data);
  }
}

void EncodeSOS(j_compress_ptr cinfo, int scan_index) {
  jpeg_comp_master* m = cinfo->master;
  const jpeg_scan_info* scan_info = &cinfo->scan_info[scan_index];
  const size_t marker_len = 6 + 2 * scan_info->comps_in_scan;
  std::vector<uint8_t> data(marker_len + 2);
  size_t pos = 0;
  data[pos++] = 0xFF;
  data[pos++] = 0xDA;
  data[pos++] = marker_len >> 8u;
  data[pos++] = marker_len & 0xFFu;
  data[pos++] = scan_info->comps_in_scan;
  for (int i = 0; i < scan_info->comps_in_scan; ++i) {
    int comp_idx = scan_info->component_index[i];
    data[pos++] = cinfo->comp_info[comp_idx].component_id;
    int dc_slot_id = m->slot_id_map[m->context_map[comp_idx]];
    int ac_context = m->ac_ctx_offset[scan_index] + i;
    int ac_slot_id = m->slot_id_map[m->context_map[ac_context]];
    data[pos++] = (dc_slot_id << 4u) + (ac_slot_id - 16);
  }
  data[pos++] = scan_info->Ss;
  data[pos++] = scan_info->Se;
  data[pos++] = ((scan_info->Ah << 4u) | (scan_info->Al));
  WriteOutput(cinfo, data);
}

void WriteScanHeader(j_compress_ptr cinfo, int scan_index) {
  jpeg_comp_master* m = cinfo->master;
  const jpeg_scan_info* scan_info = &cinfo->scan_info[scan_index];
  cinfo->restart_interval = m->scan_token_info[scan_index].restart_interval;
  if (cinfo->restart_interval != m->last_restart_interval) {
    EncodeDRI(cinfo);
    m->last_restart_interval = cinfo->restart_interval;
  }
  size_t num_dht = 0;
  if (scan_index == 0) {
    // For the first scan we emit all DC and at most 4 AC Huffman codes.
    for (size_t i = 0, num_ac = 0; i < m->num_huffman_tables; ++i) {
      if (m->slot_id_map[i] >= 16 && num_ac++ >= 4) break;
      ++num_dht;
    }
  } else if (scan_info->Ss > 0) {
    // For multi-scan sequential and progressive DC scans we have already
    // emitted all Huffman codes that we need before the first scan. For
    // progressive AC scans we only need at most one new Huffman code.
    if (m->context_map[m->ac_ctx_offset[scan_index]] == m->next_dht_index) {
      num_dht = 1;
    }
  }
  if (num_dht > 0) {
    EncodeDHT(cinfo, m->next_dht_index, num_dht);
    m->next_dht_index += num_dht;
  }
  EncodeSOS(cinfo, scan_index);
}

void WriteBlock(const int32_t* JXL_RESTRICT symbols,
                const int32_t* JXL_RESTRICT extra_bits, const int num_nonzeros,
                const bool emit_eob,
                const HuffmanCodeTable* JXL_RESTRICT dc_code,
                const HuffmanCodeTable* JXL_RESTRICT ac_code,
                JpegBitWriter* JXL_RESTRICT bw) {
  int symbol = symbols[0];
  WriteBits(bw, dc_code->depth[symbol], dc_code->code[symbol] | extra_bits[0]);
  for (int i = 1; i < num_nonzeros; ++i) {
    symbol = symbols[i];
    if (symbol > 255) {
      WriteBits(bw, ac_code->depth[0xf0], ac_code->code[0xf0]);
      symbol -= 256;
      if (symbol > 255) {
        WriteBits(bw, ac_code->depth[0xf0], ac_code->code[0xf0]);
        symbol -= 256;
        if (symbol > 255) {
          WriteBits(bw, ac_code->depth[0xf0], ac_code->code[0xf0]);
          symbol -= 256;
        }
      }
    }
    WriteBits(bw, ac_code->depth[symbol],
              ac_code->code[symbol] | extra_bits[i]);
  }
  if (emit_eob) {
    WriteBits(bw, ac_code->depth[0], ac_code->code[0]);
  }
}

namespace {

static JXL_INLINE void EmitMarker(JpegBitWriter* bw, int marker) {
  bw->data[bw->pos++] = 0xFF;
  bw->data[bw->pos++] = marker;
}

void WriteTokens(j_compress_ptr cinfo, int scan_index, JpegBitWriter* bw) {
  jpeg_comp_master* m = cinfo->master;
  HuffmanCodeTable* coding_tables = &m->coding_tables[0];
  int next_restart_marker = 0;
  const ScanTokenInfo& sti = m->scan_token_info[scan_index];
  size_t num_token_arrays = m->cur_token_array + 1;
  size_t total_tokens = 0;
  size_t restart_idx = 0;
  size_t next_restart = sti.restarts[restart_idx];
  uint8_t* context_map = m->context_map;
  for (size_t i = 0; i < num_token_arrays; ++i) {
    Token* tokens = m->token_arrays[i].tokens;
    size_t num_tokens = m->token_arrays[i].num_tokens;
    if (sti.token_offset < total_tokens + num_tokens &&
        total_tokens < sti.token_offset + sti.num_tokens) {
      size_t start_ix =
          total_tokens < sti.token_offset ? sti.token_offset - total_tokens : 0;
      size_t end_ix = std::min(sti.token_offset + sti.num_tokens - total_tokens,
                               num_tokens);
      size_t cycle_len = bw->len / 8;
      size_t next_cycle = cycle_len;
      for (size_t i = start_ix; i < end_ix; ++i) {
        if (total_tokens + i == next_restart) {
          JumpToByteBoundary(bw);
          EmitMarker(bw, 0xD0 + next_restart_marker);
          next_restart_marker += 1;
          next_restart_marker &= 0x7;
          next_restart = sti.restarts[++restart_idx];
        }
        Token t = tokens[i];
        const HuffmanCodeTable* code = &coding_tables[context_map[t.context]];
        WriteBits(bw, code->depth[t.symbol], code->code[t.symbol] | t.bits);
        if (--next_cycle == 0) {
          if (!EmptyBitWriterBuffer(bw)) {
            JPEGLI_ERROR(
                "Output suspension is not supported in "
                "finish_compress");
          }
          next_cycle = cycle_len;
        }
      }
    }
    total_tokens += num_tokens;
  }
}

void WriteACRefinementTokens(j_compress_ptr cinfo, int scan_index,
                             JpegBitWriter* bw) {
  jpeg_comp_master* m = cinfo->master;
  const ScanTokenInfo& sti = m->scan_token_info[scan_index];
  const uint8_t context = m->ac_ctx_offset[scan_index];
  const HuffmanCodeTable* code = &m->coding_tables[m->context_map[context]];
  size_t cycle_len = bw->len / 64;
  size_t next_cycle = cycle_len;
  size_t refbit_idx = 0;
  size_t eobrun_idx = 0;
  size_t restart_idx = 0;
  size_t next_restart = sti.restarts[restart_idx];
  int next_restart_marker = 0;
  for (size_t i = 0; i < sti.num_tokens; ++i) {
    if (i == next_restart) {
      JumpToByteBoundary(bw);
      EmitMarker(bw, 0xD0 + next_restart_marker);
      next_restart_marker += 1;
      next_restart_marker &= 0x7;
      next_restart = sti.restarts[++restart_idx];
    }
    RefToken t = sti.tokens[i];
    int symbol = t.symbol & 253;
    uint16_t bits = 0;
    if ((symbol & 1) == 0) {
      int r = symbol >> 4;
      if (r > 0 && r < 15) {
        bits = sti.eobruns[eobrun_idx++];
      }
    } else {
      bits = (t.symbol >> 1) & 1;
    }
    WriteBits(bw, code->depth[symbol], code->code[symbol] | bits);
    for (int j = 0; j < t.refbits; ++j) {
      WriteBits(bw, 1, sti.refbits[refbit_idx++]);
    }
    if (--next_cycle == 0) {
      if (!EmptyBitWriterBuffer(bw)) {
        JPEGLI_ERROR("Output suspension is not supported in finish_compress");
      }
      next_cycle = cycle_len;
    }
  }
}

void WriteDCRefinementBits(j_compress_ptr cinfo, int scan_index,
                           JpegBitWriter* bw) {
  jpeg_comp_master* m = cinfo->master;
  const ScanTokenInfo& sti = m->scan_token_info[scan_index];
  size_t restart_idx = 0;
  size_t next_restart = sti.restarts[restart_idx];
  int next_restart_marker = 0;
  size_t cycle_len = bw->len * 4;
  size_t next_cycle = cycle_len;
  size_t refbit_idx = 0;
  for (size_t i = 0; i < sti.num_tokens; ++i) {
    if (i == next_restart) {
      JumpToByteBoundary(bw);
      EmitMarker(bw, 0xD0 + next_restart_marker);
      next_restart_marker += 1;
      next_restart_marker &= 0x7;
      next_restart = sti.restarts[++restart_idx];
    }
    WriteBits(bw, 1, sti.refbits[refbit_idx++]);
    if (--next_cycle == 0) {
      if (!EmptyBitWriterBuffer(bw)) {
        JPEGLI_ERROR(
            "Output suspension is not supported in "
            "finish_compress");
      }
      next_cycle = cycle_len;
    }
  }
}

}  // namespace

void WriteScanData(j_compress_ptr cinfo, int scan_index) {
  const jpeg_scan_info* scan_info = &cinfo->scan_info[scan_index];
  JpegBitWriter* bw = &cinfo->master->bw;
  if (scan_info->Ah == 0) {
    WriteTokens(cinfo, scan_index, bw);
  } else if (scan_info->Ss > 0) {
    WriteACRefinementTokens(cinfo, scan_index, bw);
  } else {
    WriteDCRefinementBits(cinfo, scan_index, bw);
  }
  if (!bw->healthy) {
    JPEGLI_ERROR("Unknown Huffman coded symbol found in scan %d", scan_index);
  }
  JumpToByteBoundary(bw);
  if (!EmptyBitWriterBuffer(bw)) {
    JPEGLI_ERROR("Output suspension is not supported in finish_compress");
  }
}

}  // namespace jpegli
