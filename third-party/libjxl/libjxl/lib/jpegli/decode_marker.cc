// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/decode_marker.h"

#include <string.h>

#include "lib/jpegli/common.h"
#include "lib/jpegli/decode_internal.h"
#include "lib/jpegli/error.h"
#include "lib/jpegli/huffman.h"
#include "lib/jpegli/memory_manager.h"
#include "lib/jxl/base/printf_macros.h"

namespace jpegli {
namespace {

constexpr int kMaxDimPixels = 65535;
constexpr uint8_t kIccProfileTag[12] = "ICC_PROFILE";

// Macros for commonly used error conditions.

#define JPEG_VERIFY_LEN(n)                                      \
  if (pos + (n) > len) {                                        \
    return JPEGLI_ERROR("Unexpected end of marker: pos=%" PRIuS \
                        " need=%d len=%" PRIuS,                 \
                        pos, static_cast<int>(n), len);         \
  }

#define JPEG_VERIFY_INPUT(var, low, high)                               \
  if ((var) < (low) || (var) > (high)) {                                \
    return JPEGLI_ERROR("Invalid " #var ": %d", static_cast<int>(var)); \
  }

#define JPEG_VERIFY_MARKER_END()                                  \
  if (pos != len) {                                               \
    return JPEGLI_ERROR("Invalid marker length: declared=%" PRIuS \
                        " actual=%" PRIuS,                        \
                        len, pos);                                \
  }

inline int ReadUint8(const uint8_t* data, size_t* pos) {
  return data[(*pos)++];
}

inline int ReadUint16(const uint8_t* data, size_t* pos) {
  int v = (data[*pos] << 8) + data[*pos + 1];
  *pos += 2;
  return v;
}

void ProcessSOF(j_decompress_ptr cinfo, const uint8_t* data, size_t len) {
  jpeg_decomp_master* m = cinfo->master;
  if (!m->found_soi_) {
    JPEGLI_ERROR("Unexpected SOF marker.");
  }
  if (m->found_sof_) {
    JPEGLI_ERROR("Duplicate SOF marker.");
  }
  m->found_sof_ = true;
  cinfo->progressive_mode = (cinfo->unread_marker == 0xc2);
  cinfo->arith_code = 0;
  size_t pos = 2;
  JPEG_VERIFY_LEN(6);
  cinfo->data_precision = ReadUint8(data, &pos);
  cinfo->image_height = ReadUint16(data, &pos);
  cinfo->image_width = ReadUint16(data, &pos);
  cinfo->num_components = ReadUint8(data, &pos);
  JPEG_VERIFY_INPUT(cinfo->data_precision, kJpegPrecision, kJpegPrecision);
  JPEG_VERIFY_INPUT(cinfo->image_height, 1, kMaxDimPixels);
  JPEG_VERIFY_INPUT(cinfo->image_width, 1, kMaxDimPixels);
  JPEG_VERIFY_INPUT(cinfo->num_components, 1, kMaxComponents);
  JPEG_VERIFY_LEN(3 * cinfo->num_components);
  cinfo->comp_info = jpegli::Allocate<jpeg_component_info>(
      cinfo, cinfo->num_components, JPOOL_IMAGE);

  // Read sampling factors and quant table index for each component.
  uint8_t ids_seen[256] = {0};
  cinfo->max_h_samp_factor = 1;
  cinfo->max_v_samp_factor = 1;
  for (int i = 0; i < cinfo->num_components; ++i) {
    jpeg_component_info* comp = &cinfo->comp_info[i];
    comp->component_index = i;
    const int id = ReadUint8(data, &pos);
    if (ids_seen[id]) {  // (cf. section B.2.2, syntax of Ci)
      JPEGLI_ERROR("Duplicate ID %d in SOF.", id);
    }
    ids_seen[id] = 1;
    comp->component_id = id;
    int factor = ReadUint8(data, &pos);
    int h_samp_factor = factor >> 4;
    int v_samp_factor = factor & 0xf;
    JPEG_VERIFY_INPUT(h_samp_factor, 1, MAX_SAMP_FACTOR);
    JPEG_VERIFY_INPUT(v_samp_factor, 1, MAX_SAMP_FACTOR);
    comp->h_samp_factor = h_samp_factor;
    comp->v_samp_factor = v_samp_factor;
    cinfo->max_h_samp_factor =
        std::max(cinfo->max_h_samp_factor, h_samp_factor);
    cinfo->max_v_samp_factor =
        std::max(cinfo->max_v_samp_factor, v_samp_factor);
    int quant_tbl_idx = ReadUint8(data, &pos);
    JPEG_VERIFY_INPUT(quant_tbl_idx, 0, NUM_QUANT_TBLS - 1);
    comp->quant_tbl_no = quant_tbl_idx;
    if (cinfo->quant_tbl_ptrs[quant_tbl_idx] == nullptr) {
      JPEGLI_ERROR("Quantization table with index %u not found", quant_tbl_idx);
    }
    comp->quant_table = nullptr;  // will be allocated after SOS marker
  }
  JPEG_VERIFY_MARKER_END();

  // Set the input colorspace based on the markers we have seen and set
  // default output colorspace.
  if (cinfo->num_components == 1) {
    cinfo->jpeg_color_space = JCS_GRAYSCALE;
    cinfo->out_color_space = JCS_GRAYSCALE;
  } else if (cinfo->num_components == 3) {
    if (cinfo->saw_JFIF_marker) {
      cinfo->jpeg_color_space = JCS_YCbCr;
    } else if (cinfo->saw_Adobe_marker) {
      cinfo->jpeg_color_space =
          cinfo->Adobe_transform == 0 ? JCS_RGB : JCS_YCbCr;
    } else {
      cinfo->jpeg_color_space = JCS_YCbCr;
      if (cinfo->comp_info[0].component_id == 'R' &&  //
          cinfo->comp_info[1].component_id == 'G' &&  //
          cinfo->comp_info[2].component_id == 'B') {
        cinfo->jpeg_color_space = JCS_RGB;
      }
    }
    cinfo->out_color_space = JCS_RGB;
  } else if (cinfo->num_components == 4) {
    if (cinfo->saw_Adobe_marker) {
      cinfo->jpeg_color_space =
          cinfo->Adobe_transform == 0 ? JCS_CMYK : JCS_YCCK;
    } else {
      cinfo->jpeg_color_space = JCS_CMYK;
    }
    cinfo->out_color_space = JCS_CMYK;
  }

  // We have checked above that none of the sampling factors are 0, so the max
  // sampling factors can not be 0.
  cinfo->total_iMCU_rows =
      DivCeil(cinfo->image_height, cinfo->max_v_samp_factor * DCTSIZE);
  m->iMCU_cols_ =
      DivCeil(cinfo->image_width, cinfo->max_h_samp_factor * DCTSIZE);
  // Compute the block dimensions for each component.
  for (int i = 0; i < cinfo->num_components; ++i) {
    jpeg_component_info* comp = &cinfo->comp_info[i];
    if (cinfo->max_h_samp_factor % comp->h_samp_factor != 0 ||
        cinfo->max_v_samp_factor % comp->v_samp_factor != 0) {
      JPEGLI_ERROR("Non-integral subsampling ratios.");
    }
    m->h_factor[i] = cinfo->max_h_samp_factor / comp->h_samp_factor;
    m->v_factor[i] = cinfo->max_v_samp_factor / comp->v_samp_factor;
    comp->downsampled_width = DivCeil(cinfo->image_width, m->h_factor[i]);
    comp->downsampled_height = DivCeil(cinfo->image_height, m->v_factor[i]);
    comp->width_in_blocks = DivCeil(comp->downsampled_width, DCTSIZE);
    comp->height_in_blocks = DivCeil(comp->downsampled_height, DCTSIZE);
  }
  memset(m->scan_progression_, 0, sizeof(m->scan_progression_));
}

void ProcessSOS(j_decompress_ptr cinfo, const uint8_t* data, size_t len) {
  jpeg_decomp_master* m = cinfo->master;
  if (!m->found_sof_) {
    JPEGLI_ERROR("Unexpected SOS marker.");
  }
  size_t pos = 2;
  JPEG_VERIFY_LEN(1);
  cinfo->comps_in_scan = ReadUint8(data, &pos);
  JPEG_VERIFY_INPUT(cinfo->comps_in_scan, 1, cinfo->num_components);
  JPEG_VERIFY_INPUT(cinfo->comps_in_scan, 1, MAX_COMPS_IN_SCAN);

  JPEG_VERIFY_LEN(2 * cinfo->comps_in_scan);
  bool is_interleaved = (cinfo->comps_in_scan > 1);
  uint8_t ids_seen[256] = {0};
  cinfo->blocks_in_MCU = 0;
  for (int i = 0; i < cinfo->comps_in_scan; ++i) {
    int id = ReadUint8(data, &pos);
    if (ids_seen[id]) {  // (cf. section B.2.3, regarding CSj)
      return JPEGLI_ERROR("Duplicate ID %d in SOS.", id);
    }
    ids_seen[id] = 1;
    jpeg_component_info* comp = nullptr;
    for (int j = 0; j < cinfo->num_components; ++j) {
      if (cinfo->comp_info[j].component_id == id) {
        comp = &cinfo->comp_info[j];
        cinfo->cur_comp_info[i] = comp;
      }
    }
    if (!comp) {
      return JPEGLI_ERROR("SOS marker: Could not find component with id %d",
                          id);
    }
    int c = ReadUint8(data, &pos);
    comp->dc_tbl_no = c >> 4;
    comp->ac_tbl_no = c & 0xf;
    JPEG_VERIFY_INPUT(comp->dc_tbl_no, 0, 3);
    JPEG_VERIFY_INPUT(comp->ac_tbl_no, 0, 3);
    comp->MCU_width = is_interleaved ? comp->h_samp_factor : 1;
    comp->MCU_height = is_interleaved ? comp->v_samp_factor : 1;
    comp->MCU_blocks = comp->MCU_width * comp->MCU_height;
    if (cinfo->blocks_in_MCU + comp->MCU_blocks > D_MAX_BLOCKS_IN_MCU) {
      JPEGLI_ERROR("Too many blocks in MCU.");
    }
    for (int j = 0; j < comp->MCU_blocks; ++j) {
      cinfo->MCU_membership[cinfo->blocks_in_MCU++] = i;
    }
  }
  JPEG_VERIFY_LEN(3);
  cinfo->Ss = ReadUint8(data, &pos);
  cinfo->Se = ReadUint8(data, &pos);
  JPEG_VERIFY_INPUT(cinfo->Ss, 0, 63);
  JPEG_VERIFY_INPUT(cinfo->Se, cinfo->Ss, 63);
  int c = ReadUint8(data, &pos);
  cinfo->Ah = c >> 4;
  cinfo->Al = c & 0xf;
  JPEG_VERIFY_MARKER_END();

  if (cinfo->input_scan_number == 0) {
    m->is_multiscan_ = (cinfo->comps_in_scan < cinfo->num_components ||
                        cinfo->progressive_mode);
  }
  if (cinfo->Ah != 0 && cinfo->Al != cinfo->Ah - 1) {
    // section G.1.1.1.2 : Successive approximation control only improves
    // by one bit at a time.
    JPEGLI_ERROR("Invalid progressive parameters: Al=%d Ah=%d", cinfo->Al,
                 cinfo->Ah);
  }
  if (!cinfo->progressive_mode) {
    cinfo->Ss = 0;
    cinfo->Se = 63;
    cinfo->Ah = 0;
    cinfo->Al = 0;
  }
  const uint16_t scan_bitmask =
      cinfo->Ah == 0 ? (0xffff << cinfo->Al) : (1u << cinfo->Al);
  const uint16_t refinement_bitmask = (1 << cinfo->Al) - 1;
  if (!cinfo->coef_bits) {
    cinfo->coef_bits =
        Allocate<int[DCTSIZE2]>(cinfo, cinfo->num_components * 2, JPOOL_IMAGE);
    m->coef_bits_latch =
        Allocate<int[SAVED_COEFS]>(cinfo, cinfo->num_components, JPOOL_IMAGE);
    m->prev_coef_bits_latch =
        Allocate<int[SAVED_COEFS]>(cinfo, cinfo->num_components, JPOOL_IMAGE);

    for (int c = 0; c < cinfo->num_components; ++c) {
      for (int i = 0; i < DCTSIZE2; ++i) {
        cinfo->coef_bits[c][i] = -1;
        if (i < SAVED_COEFS) {
          m->coef_bits_latch[c][i] = -1;
        }
      }
    }
  }

  for (int i = 0; i < cinfo->comps_in_scan; ++i) {
    int comp_idx = cinfo->cur_comp_info[i]->component_index;
    for (int k = cinfo->Ss; k <= cinfo->Se; ++k) {
      if (m->scan_progression_[comp_idx][k] & scan_bitmask) {
        return JPEGLI_ERROR(
            "Overlapping scans: component=%d k=%d prev_mask: %u cur_mask %u",
            comp_idx, k, m->scan_progression_[i][k], scan_bitmask);
      }
      if (m->scan_progression_[comp_idx][k] & refinement_bitmask) {
        return JPEGLI_ERROR(
            "Invalid scan order, a more refined scan was already done: "
            "component=%d k=%d prev_mask=%u cur_mask=%u",
            comp_idx, k, m->scan_progression_[i][k], scan_bitmask);
      }
      m->scan_progression_[comp_idx][k] |= scan_bitmask;
    }
  }
  if (cinfo->Al > 10) {
    return JPEGLI_ERROR("Scan parameter Al=%d is not supported.", cinfo->Al);
  }
}

// Reads the Define Huffman Table (DHT) marker segment and builds the Huffman
// decoding table in either dc_huff_lut_ or ac_huff_lut_, depending on the type
// and solt_id of Huffman code being read.
void ProcessDHT(j_decompress_ptr cinfo, const uint8_t* data, size_t len) {
  size_t pos = 2;
  if (pos == len) {
    return JPEGLI_ERROR("DHT marker: no Huffman table found");
  }
  while (pos < len) {
    JPEG_VERIFY_LEN(1 + kJpegHuffmanMaxBitLength);
    // The index of the Huffman code in the current set of Huffman codes. For AC
    // component Huffman codes, 0x10 is added to the index.
    int slot_id = ReadUint8(data, &pos);
    int huffman_index = slot_id;
    int is_ac_table = (slot_id & 0x10) != 0;
    JHUFF_TBL** table;
    if (is_ac_table) {
      huffman_index -= 0x10;
      JPEG_VERIFY_INPUT(huffman_index, 0, NUM_HUFF_TBLS - 1);
      table = &cinfo->ac_huff_tbl_ptrs[huffman_index];
    } else {
      JPEG_VERIFY_INPUT(huffman_index, 0, NUM_HUFF_TBLS - 1);
      table = &cinfo->dc_huff_tbl_ptrs[huffman_index];
    }
    if (*table == nullptr) {
      *table = jpegli_alloc_huff_table(reinterpret_cast<j_common_ptr>(cinfo));
    }
    int total_count = 0;
    for (size_t i = 1; i <= kJpegHuffmanMaxBitLength; ++i) {
      int count = ReadUint8(data, &pos);
      (*table)->bits[i] = count;
      total_count += count;
    }
    if (is_ac_table) {
      JPEG_VERIFY_INPUT(total_count, 0, kJpegHuffmanAlphabetSize);
    } else {
      // Allow symbols up to 15 here, we check later whether any invalid symbols
      // are actually decoded.
      // TODO(szabadka) Make sure decoder works (does not crash) with up to
      // 15-nbits DC symbols and then increase kJpegDCAlphabetSize.
      JPEG_VERIFY_INPUT(total_count, 0, 16);
    }
    JPEG_VERIFY_LEN(total_count);
    for (int i = 0; i < total_count; ++i) {
      int value = ReadUint8(data, &pos);
      if (!is_ac_table) {
        JPEG_VERIFY_INPUT(value, 0, 15);
      }
      (*table)->huffval[i] = value;
    }
    for (int i = total_count; i < kJpegHuffmanAlphabetSize; ++i) {
      (*table)->huffval[i] = 0;
    }
  }
  JPEG_VERIFY_MARKER_END();
}

void ProcessDQT(j_decompress_ptr cinfo, const uint8_t* data, size_t len) {
  jpeg_decomp_master* m = cinfo->master;
  if (m->found_sof_) {
    JPEGLI_ERROR("Updating quant tables between scans is not supported.");
  }
  size_t pos = 2;
  if (pos == len) {
    return JPEGLI_ERROR("DQT marker: no quantization table found");
  }
  while (pos < len) {
    JPEG_VERIFY_LEN(1);
    int quant_table_index = ReadUint8(data, &pos);
    int precision = quant_table_index >> 4;
    JPEG_VERIFY_INPUT(precision, 0, 1);
    quant_table_index &= 0xf;
    JPEG_VERIFY_INPUT(quant_table_index, 0, NUM_QUANT_TBLS - 1);
    JPEG_VERIFY_LEN((precision + 1) * DCTSIZE2);

    if (cinfo->quant_tbl_ptrs[quant_table_index] == nullptr) {
      cinfo->quant_tbl_ptrs[quant_table_index] =
          jpegli_alloc_quant_table(reinterpret_cast<j_common_ptr>(cinfo));
    }
    JQUANT_TBL* quant_table = cinfo->quant_tbl_ptrs[quant_table_index];

    for (size_t i = 0; i < DCTSIZE2; ++i) {
      int quant_val =
          precision ? ReadUint16(data, &pos) : ReadUint8(data, &pos);
      JPEG_VERIFY_INPUT(quant_val, 1, 65535);
      quant_table->quantval[kJPEGNaturalOrder[i]] = quant_val;
    }
  }
  JPEG_VERIFY_MARKER_END();
}

void ProcessDNL(j_decompress_ptr cinfo, const uint8_t* data, size_t len) {
  // Ignore marker.
}

void ProcessDRI(j_decompress_ptr cinfo, const uint8_t* data, size_t len) {
  jpeg_decomp_master* m = cinfo->master;
  if (m->found_dri_) {
    return JPEGLI_ERROR("Duplicate DRI marker.");
  }
  m->found_dri_ = true;
  size_t pos = 2;
  JPEG_VERIFY_LEN(2);
  cinfo->restart_interval = ReadUint16(data, &pos);
  JPEG_VERIFY_MARKER_END();
}

void ProcessAPP(j_decompress_ptr cinfo, const uint8_t* data, size_t len) {
  jpeg_decomp_master* m = cinfo->master;
  const uint8_t marker = cinfo->unread_marker;
  const uint8_t* payload = data + 2;
  size_t payload_size = len - 2;
  if (marker == 0xE0) {
    if (payload_size >= 14 && memcmp(payload, "JFIF", 4) == 0) {
      cinfo->saw_JFIF_marker = TRUE;
      cinfo->JFIF_major_version = payload[5];
      cinfo->JFIF_minor_version = payload[6];
      cinfo->density_unit = payload[7];
      cinfo->X_density = (payload[8] << 8) + payload[9];
      cinfo->Y_density = (payload[10] << 8) + payload[11];
    }
  } else if (marker == 0xEE) {
    if (payload_size >= 12 && memcmp(payload, "Adobe", 5) == 0) {
      cinfo->saw_Adobe_marker = TRUE;
      cinfo->Adobe_transform = payload[11];
    }
  } else if (marker == 0xE2) {
    if (payload_size >= sizeof(kIccProfileTag) &&
        memcmp(payload, kIccProfileTag, sizeof(kIccProfileTag)) == 0) {
      payload += sizeof(kIccProfileTag);
      payload_size -= sizeof(kIccProfileTag);
      if (payload_size < 2) {
        return JPEGLI_ERROR("ICC chunk is too small.");
      }
      uint8_t index = payload[0];
      uint8_t total = payload[1];
      ++m->icc_index_;
      if (m->icc_index_ != index) {
        return JPEGLI_ERROR("Invalid ICC chunk order.");
      }
      if (total == 0) {
        return JPEGLI_ERROR("Invalid ICC chunk total.");
      }
      if (m->icc_total_ == 0) {
        m->icc_total_ = total;
      } else if (m->icc_total_ != total) {
        return JPEGLI_ERROR("Invalid ICC chunk total.");
      }
      if (m->icc_index_ > m->icc_total_) {
        return JPEGLI_ERROR("Invalid ICC chunk index.");
      }
      m->icc_profile_.insert(m->icc_profile_.end(), payload + 2,
                             payload + payload_size);
    }
  }
}

void ProcessCOM(j_decompress_ptr cinfo, const uint8_t* data, size_t len) {
  // Ignore marker.
}

void ProcessSOI(j_decompress_ptr cinfo, const uint8_t* data, size_t len) {
  jpeg_decomp_master* m = cinfo->master;
  if (m->found_soi_) {
    JPEGLI_ERROR("Duplicate SOI marker");
  }
  m->found_soi_ = true;
}

void ProcessEOI(j_decompress_ptr cinfo, const uint8_t* data, size_t len) {
  cinfo->master->found_eoi_ = true;
}

void SaveMarker(j_decompress_ptr cinfo, const uint8_t* data, size_t len) {
  const uint8_t marker = cinfo->unread_marker;
  const uint8_t* payload = data + 2;
  size_t payload_size = len - 2;

  // Insert new saved marker to the head of the list.
  jpeg_saved_marker_ptr next = cinfo->marker_list;
  cinfo->marker_list =
      jpegli::Allocate<jpeg_marker_struct>(cinfo, 1, JPOOL_IMAGE);
  cinfo->marker_list->next = next;
  cinfo->marker_list->marker = marker;
  cinfo->marker_list->original_length = payload_size;
  cinfo->marker_list->data_length = payload_size;
  cinfo->marker_list->data =
      jpegli::Allocate<uint8_t>(cinfo, payload_size, JPOOL_IMAGE);
  memcpy(cinfo->marker_list->data, payload, payload_size);
}

uint8_t ProcessNextMarker(j_decompress_ptr cinfo, const uint8_t* const data,
                          const size_t len, size_t* pos) {
  jpeg_decomp_master* m = cinfo->master;
  size_t num_skipped = 0;
  uint8_t marker = cinfo->unread_marker;
  if (marker == 0) {
    // kIsValidMarker[i] == 1 means (0xc0 + i) is a valid marker.
    static const uint8_t kIsValidMarker[] = {
        1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0,
    };
    // Skip bytes between markers.
    while (*pos + 1 < len && (data[*pos] != 0xff || data[*pos + 1] < 0xc0 ||
                              !kIsValidMarker[data[*pos + 1] - 0xc0])) {
      ++(*pos);
      ++num_skipped;
    }
    if (*pos + 2 > len) {
      return kNeedMoreInput;
    }
    marker = data[*pos + 1];
    if (num_skipped > 0) {
      if (m->found_soi_) {
        JPEGLI_WARN("Skipped %d bytes before marker 0x%02x", (int)num_skipped,
                    marker);
      } else {
        JPEGLI_ERROR("Did not find SOI marker.");
      }
    }
    *pos += 2;
    cinfo->unread_marker = marker;
  }
  if (!m->found_soi_ && marker != 0xd8) {
    JPEGLI_ERROR("Did not find SOI marker.");
  }
  if (GetMarkerProcessor(cinfo)) {
    return kHandleMarkerProcessor;
  }
  const uint8_t* marker_data = &data[*pos];
  size_t marker_len = 0;
  if (marker != 0xd8 && marker != 0xd9) {
    if (*pos + 2 > len) {
      return kNeedMoreInput;
    }
    marker_len += (data[*pos] << 8) + data[*pos + 1];
    if (marker_len < 2) {
      JPEGLI_ERROR("Invalid marker length");
    }
    if (*pos + marker_len > len) {
      // TODO(szabadka) Limit our memory usage by using the skip_input_data
      // source manager callback on APP markers that are not saved.
      return kNeedMoreInput;
    }
    if (marker >= 0xe0 && m->markers_to_save_[marker - 0xe0]) {
      SaveMarker(cinfo, marker_data, marker_len);
    }
  }
  if (marker == 0xc0 || marker == 0xc1 || marker == 0xc2) {
    ProcessSOF(cinfo, marker_data, marker_len);
  } else if (marker == 0xc4) {
    ProcessDHT(cinfo, marker_data, marker_len);
  } else if (marker == 0xda) {
    ProcessSOS(cinfo, marker_data, marker_len);
  } else if (marker == 0xdb) {
    ProcessDQT(cinfo, marker_data, marker_len);
  } else if (marker == 0xdc) {
    ProcessDNL(cinfo, marker_data, marker_len);
  } else if (marker == 0xdd) {
    ProcessDRI(cinfo, marker_data, marker_len);
  } else if (marker >= 0xe0 && marker <= 0xef) {
    ProcessAPP(cinfo, marker_data, marker_len);
  } else if (marker == 0xfe) {
    ProcessCOM(cinfo, marker_data, marker_len);
  } else if (marker == 0xd8) {
    ProcessSOI(cinfo, marker_data, marker_len);
  } else if (marker == 0xd9) {
    ProcessEOI(cinfo, marker_data, marker_len);
  } else {
    JPEGLI_ERROR("Unexpected marker 0x%x", marker);
  }
  *pos += marker_len;
  cinfo->unread_marker = 0;
  if (marker == 0xda) {
    return JPEG_REACHED_SOS;
  } else if (marker == 0xd9) {
    return JPEG_REACHED_EOI;
  }
  return kProcessNextMarker;
}

}  // namespace

jpeg_marker_parser_method GetMarkerProcessor(j_decompress_ptr cinfo) {
  jpeg_decomp_master* m = cinfo->master;
  uint8_t marker = cinfo->unread_marker;
  jpeg_marker_parser_method callback = nullptr;
  if (marker >= 0xe0 && marker <= 0xef) {
    callback = m->app_marker_parsers[marker - 0xe0];
  } else if (marker == 0xfe) {
    callback = m->com_marker_parser;
  }
  return callback;
}

int ProcessMarkers(j_decompress_ptr cinfo, const uint8_t* const data,
                   const size_t len, size_t* pos) {
  for (;;) {
    int status = ProcessNextMarker(cinfo, data, len, pos);
    if (status != kProcessNextMarker) {
      return status;
    }
  }
}

}  // namespace jpegli
