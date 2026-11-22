// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/jpeg/jpeg_data.h"

#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/status.h"

namespace jxl {
namespace jpeg {

#if JPEGXL_ENABLE_TRANSCODE_JPEG

namespace {
enum JPEGComponentType : uint32_t {
  kGray = 0,
  kYCbCr = 1,
  kRGB = 2,
  kCustom = 3,
};

struct JPEGInfo {
  size_t num_app_markers = 0;
  size_t num_com_markers = 0;
  size_t num_scans = 0;
  size_t num_intermarker = 0;
  bool has_dri = false;
};

Status VisitMarker(uint8_t* marker, Visitor* visitor, JPEGInfo* info) {
  uint32_t marker32 = *marker - 0xc0;
  JXL_RETURN_IF_ERROR(visitor->Bits(6, 0x00, &marker32));
  *marker = marker32 + 0xc0;
  if ((*marker & 0xf0) == 0xe0) {
    info->num_app_markers++;
  }
  if (*marker == 0xfe) {
    info->num_com_markers++;
  }
  if (*marker == 0xda) {
    info->num_scans++;
  }
  // We use a fake 0xff marker to signal intermarker data.
  if (*marker == 0xff) {
    info->num_intermarker++;
  }
  if (*marker == 0xdd) {
    info->has_dri = true;
  }
  return true;
}

}  // namespace

Status JPEGData::VisitFields(Visitor* visitor) {
  bool is_gray = components.size() == 1;
  JXL_RETURN_IF_ERROR(visitor->Bool(false, &is_gray));
  if (visitor->IsReading()) {
    components.resize(is_gray ? 1 : 3);
  }
  JPEGInfo info;
  if (visitor->IsReading()) {
    uint8_t marker = 0xc0;
    do {
      JXL_RETURN_IF_ERROR(VisitMarker(&marker, visitor, &info));
      marker_order.push_back(marker);
      if (marker_order.size() > 16384) {
        return JXL_FAILURE("Too many markers: %" PRIuS "\n",
                           marker_order.size());
      }
    } while (marker != 0xd9);
  } else {
    if (marker_order.size() > 16384) {
      return JXL_FAILURE("Too many markers: %" PRIuS "\n", marker_order.size());
    }
    for (size_t i = 0; i < marker_order.size(); i++) {
      JXL_RETURN_IF_ERROR(VisitMarker(&marker_order[i], visitor, &info));
    }
    if (!marker_order.empty()) {
      // Last marker should always be EOI marker.
      JXL_CHECK(marker_order.back() == 0xd9);
    }
  }

  // Size of the APP and COM markers.
  if (visitor->IsReading()) {
    app_data.resize(info.num_app_markers);
    app_marker_type.resize(info.num_app_markers);
    com_data.resize(info.num_com_markers);
    scan_info.resize(info.num_scans);
  }
  JXL_ASSERT(app_data.size() == info.num_app_markers);
  JXL_ASSERT(app_marker_type.size() == info.num_app_markers);
  JXL_ASSERT(com_data.size() == info.num_com_markers);
  JXL_ASSERT(scan_info.size() == info.num_scans);
  for (size_t i = 0; i < app_data.size(); i++) {
    auto& app = app_data[i];
    // Encodes up to 8 different values.
    JXL_RETURN_IF_ERROR(
        visitor->U32(Val(0), Val(1), BitsOffset(1, 2), BitsOffset(2, 4), 0,
                     reinterpret_cast<uint32_t*>(&app_marker_type[i])));
    if (app_marker_type[i] != AppMarkerType::kUnknown &&
        app_marker_type[i] != AppMarkerType::kICC &&
        app_marker_type[i] != AppMarkerType::kExif &&
        app_marker_type[i] != AppMarkerType::kXMP) {
      return JXL_FAILURE("Unknown app marker type %u",
                         static_cast<uint32_t>(app_marker_type[i]));
    }
    uint32_t len = app.size() - 1;
    JXL_RETURN_IF_ERROR(visitor->Bits(16, 0, &len));
    if (visitor->IsReading()) app.resize(len + 1);
    if (app.size() < 3) {
      return JXL_FAILURE("Invalid marker size: %" PRIuS "\n", app.size());
    }
  }
  for (auto& com : com_data) {
    uint32_t len = com.size() - 1;
    JXL_RETURN_IF_ERROR(visitor->Bits(16, 0, &len));
    if (visitor->IsReading()) com.resize(len + 1);
    if (com.size() < 3) {
      return JXL_FAILURE("Invalid marker size: %" PRIuS "\n", com.size());
    }
  }

  uint32_t num_quant_tables = quant.size();
  JXL_RETURN_IF_ERROR(
      visitor->U32(Val(1), Val(2), Val(3), Val(4), 2, &num_quant_tables));
  if (num_quant_tables == 4) {
    return JXL_FAILURE("Invalid number of quant tables");
  }
  if (visitor->IsReading()) {
    quant.resize(num_quant_tables);
  }
  for (size_t i = 0; i < num_quant_tables; i++) {
    if (quant[i].precision > 1) {
      return JXL_FAILURE(
          "Quant tables with more than 16 bits are not supported");
    }
    JXL_RETURN_IF_ERROR(visitor->Bits(1, 0, &quant[i].precision));
    JXL_RETURN_IF_ERROR(visitor->Bits(2, i, &quant[i].index));
    JXL_RETURN_IF_ERROR(visitor->Bool(true, &quant[i].is_last));
  }

  JPEGComponentType component_type =
      components.size() == 1 && components[0].id == 1 ? JPEGComponentType::kGray
      : components.size() == 3 && components[0].id == 1 &&
              components[1].id == 2 && components[2].id == 3
          ? JPEGComponentType::kYCbCr
      : components.size() == 3 && components[0].id == 'R' &&
              components[1].id == 'G' && components[2].id == 'B'
          ? JPEGComponentType::kRGB
          : JPEGComponentType::kCustom;
  JXL_RETURN_IF_ERROR(
      visitor->Bits(2, JPEGComponentType::kYCbCr,
                    reinterpret_cast<uint32_t*>(&component_type)));
  uint32_t num_components;
  if (component_type == JPEGComponentType::kGray) {
    num_components = 1;
  } else if (component_type != JPEGComponentType::kCustom) {
    num_components = 3;
  } else {
    num_components = components.size();
    JXL_RETURN_IF_ERROR(
        visitor->U32(Val(1), Val(2), Val(3), Val(4), 3, &num_components));
    if (num_components != 1 && num_components != 3) {
      return JXL_FAILURE("Invalid number of components: %u", num_components);
    }
  }
  if (visitor->IsReading()) {
    components.resize(num_components);
  }
  if (component_type == JPEGComponentType::kCustom) {
    for (size_t i = 0; i < components.size(); i++) {
      JXL_RETURN_IF_ERROR(visitor->Bits(8, 0, &components[i].id));
    }
  } else if (component_type == JPEGComponentType::kGray) {
    components[0].id = 1;
  } else if (component_type == JPEGComponentType::kRGB) {
    components[0].id = 'R';
    components[1].id = 'G';
    components[2].id = 'B';
  } else {
    components[0].id = 1;
    components[1].id = 2;
    components[2].id = 3;
  }
  size_t used_tables = 0;
  for (size_t i = 0; i < components.size(); i++) {
    JXL_RETURN_IF_ERROR(visitor->Bits(2, 0, &components[i].quant_idx));
    if (components[i].quant_idx >= quant.size()) {
      return JXL_FAILURE("Invalid quant table for component %" PRIuS ": %u\n",
                         i, components[i].quant_idx);
    }
    used_tables |= 1U << components[i].quant_idx;
  }
  for (size_t i = 0; i < quant.size(); i++) {
    if (used_tables & (1 << i)) continue;
    if (i == 0) return JXL_FAILURE("First quant table unused.");
    // Unused quant table has to be set to copy of previous quant table
    for (size_t j = 0; j < 64; j++) {
      if (quant[i].values[j] != quant[i - 1].values[j]) {
        return JXL_FAILURE("Non-trivial unused quant table");
      }
    }
  }

  uint32_t num_huff = huffman_code.size();
  JXL_RETURN_IF_ERROR(visitor->U32(Val(4), BitsOffset(3, 2), BitsOffset(4, 10),
                                   BitsOffset(6, 26), 4, &num_huff));
  if (visitor->IsReading()) {
    huffman_code.resize(num_huff);
  }
  for (JPEGHuffmanCode& hc : huffman_code) {
    bool is_ac = hc.slot_id >> 4;
    uint32_t id = hc.slot_id & 0xF;
    JXL_RETURN_IF_ERROR(visitor->Bool(false, &is_ac));
    JXL_RETURN_IF_ERROR(visitor->Bits(2, 0, &id));
    hc.slot_id = (static_cast<uint32_t>(is_ac) << 4) | id;
    JXL_RETURN_IF_ERROR(visitor->Bool(true, &hc.is_last));
    size_t num_symbols = 0;
    for (size_t i = 0; i <= 16; i++) {
      JXL_RETURN_IF_ERROR(visitor->U32(Val(0), Val(1), BitsOffset(3, 2),
                                       Bits(8), 0, &hc.counts[i]));
      num_symbols += hc.counts[i];
    }
    if (num_symbols < 1) {
      // Actually, at least 2 symbols are required, since one of them is EOI.
      return JXL_FAILURE("Empty Huffman table");
    }
    if (num_symbols > hc.values.size()) {
      return JXL_FAILURE("Huffman code too large (%" PRIuS ")", num_symbols);
    }
    // Presence flags for 4 * 64 + 1 values.
    uint64_t value_slots[5] = {};
    for (size_t i = 0; i < num_symbols; i++) {
      // Goes up to 256, included. Might have the same symbol appear twice...
      JXL_RETURN_IF_ERROR(visitor->U32(Bits(2), BitsOffset(2, 4),
                                       BitsOffset(4, 8), BitsOffset(8, 1), 0,
                                       &hc.values[i]));
      value_slots[hc.values[i] >> 6] |= (uint64_t)1 << (hc.values[i] & 0x3F);
    }
    if (hc.values[num_symbols - 1] != kJpegHuffmanAlphabetSize) {
      return JXL_FAILURE("Missing EOI symbol");
    }
    // Last element, denoting EOI, have to be 1 after the loop.
    JXL_ASSERT(value_slots[4] == 1);
    size_t num_values = 1;
    for (size_t i = 0; i < 4; ++i) num_values += hwy::PopCount(value_slots[i]);
    if (num_values != num_symbols) {
      return JXL_FAILURE("Duplicate Huffman symbols");
    }
    if (!is_ac) {
      bool only_dc = ((value_slots[0] >> kJpegDCAlphabetSize) | value_slots[1] |
                      value_slots[2] | value_slots[3]) == 0;
      if (!only_dc) return JXL_FAILURE("Huffman symbols out of DC range");
    }
  }

  for (auto& scan : scan_info) {
    JXL_RETURN_IF_ERROR(
        visitor->U32(Val(1), Val(2), Val(3), Val(4), 1, &scan.num_components));
    if (scan.num_components >= 4) {
      return JXL_FAILURE("Invalid number of components in SOS marker");
    }
    JXL_RETURN_IF_ERROR(visitor->Bits(6, 0, &scan.Ss));
    JXL_RETURN_IF_ERROR(visitor->Bits(6, 63, &scan.Se));
    JXL_RETURN_IF_ERROR(visitor->Bits(4, 0, &scan.Al));
    JXL_RETURN_IF_ERROR(visitor->Bits(4, 0, &scan.Ah));
    for (size_t i = 0; i < scan.num_components; i++) {
      JXL_RETURN_IF_ERROR(visitor->Bits(2, 0, &scan.components[i].comp_idx));
      if (scan.components[i].comp_idx >= components.size()) {
        return JXL_FAILURE("Invalid component idx in SOS marker");
      }
      JXL_RETURN_IF_ERROR(visitor->Bits(2, 0, &scan.components[i].ac_tbl_idx));
      JXL_RETURN_IF_ERROR(visitor->Bits(2, 0, &scan.components[i].dc_tbl_idx));
    }
    // TODO(veluca): actually set and use this value.
    JXL_RETURN_IF_ERROR(visitor->U32(Val(0), Val(1), Val(2), BitsOffset(3, 3),
                                     kMaxNumPasses - 1,
                                     &scan.last_needed_pass));
  }

  // From here on, this is data that is not strictly necessary to get a valid
  // JPEG, but necessary for bit-exact JPEG reconstruction.
  if (info.has_dri) {
    JXL_RETURN_IF_ERROR(visitor->Bits(16, 0, &restart_interval));
  }

  for (auto& scan : scan_info) {
    uint32_t num_reset_points = scan.reset_points.size();
    JXL_RETURN_IF_ERROR(visitor->U32(Val(0), BitsOffset(2, 1), BitsOffset(4, 4),
                                     BitsOffset(16, 20), 0, &num_reset_points));
    if (visitor->IsReading()) {
      scan.reset_points.resize(num_reset_points);
    }
    int last_block_idx = -1;
    for (auto& block_idx : scan.reset_points) {
      block_idx -= last_block_idx + 1;
      JXL_RETURN_IF_ERROR(visitor->U32(Val(0), BitsOffset(3, 1),
                                       BitsOffset(5, 9), BitsOffset(28, 41), 0,
                                       &block_idx));
      block_idx += last_block_idx + 1;
      if (block_idx >= (3u << 26)) {
        // At most 8K x 8K x num_channels blocks are possible in a JPEG.
        // So valid block indices are below 3 * 2^26.
        return JXL_FAILURE("Invalid block ID: %u", block_idx);
      }
      last_block_idx = block_idx;
    }

    uint32_t num_extra_zero_runs = scan.extra_zero_runs.size();
    JXL_RETURN_IF_ERROR(visitor->U32(Val(0), BitsOffset(2, 1), BitsOffset(4, 4),
                                     BitsOffset(16, 20), 0,
                                     &num_extra_zero_runs));
    if (visitor->IsReading()) {
      scan.extra_zero_runs.resize(num_extra_zero_runs);
    }
    last_block_idx = -1;
    for (size_t i = 0; i < scan.extra_zero_runs.size(); ++i) {
      uint32_t& block_idx = scan.extra_zero_runs[i].block_idx;
      JXL_RETURN_IF_ERROR(visitor->U32(
          Val(1), BitsOffset(2, 2), BitsOffset(4, 5), BitsOffset(8, 20), 1,
          &scan.extra_zero_runs[i].num_extra_zero_runs));
      block_idx -= last_block_idx + 1;
      JXL_RETURN_IF_ERROR(visitor->U32(Val(0), BitsOffset(3, 1),
                                       BitsOffset(5, 9), BitsOffset(28, 41), 0,
                                       &block_idx));
      block_idx += last_block_idx + 1;
      if (block_idx > (3u << 26)) {
        return JXL_FAILURE("Invalid block ID: %u", block_idx);
      }
      last_block_idx = block_idx;
    }
  }
  std::vector<uint32_t> inter_marker_data_sizes;
  inter_marker_data_sizes.reserve(info.num_intermarker);
  for (size_t i = 0; i < info.num_intermarker; ++i) {
    uint32_t len = visitor->IsReading() ? 0 : inter_marker_data[i].size();
    JXL_RETURN_IF_ERROR(visitor->Bits(16, 0, &len));
    if (visitor->IsReading()) inter_marker_data_sizes.emplace_back(len);
  }
  uint32_t tail_data_len = tail_data.size();
  if (!visitor->IsReading() && tail_data_len > 4260096) {
    return JXL_FAILURE("Tail data too large (max size = 4260096, size = %u)",
                       tail_data_len);
  }
  JXL_RETURN_IF_ERROR(visitor->U32(Val(0), BitsOffset(8, 1),
                                   BitsOffset(16, 257), BitsOffset(22, 65793),
                                   0, &tail_data_len));

  JXL_RETURN_IF_ERROR(visitor->Bool(false, &has_zero_padding_bit));
  if (has_zero_padding_bit) {
    uint32_t nbit = padding_bits.size();
    JXL_RETURN_IF_ERROR(visitor->Bits(24, 0, &nbit));
    if (visitor->IsReading()) {
      JXL_RETURN_IF_ERROR(CheckHasEnoughBits(visitor, nbit));
      padding_bits.reserve(std::min<uint32_t>(1024u, nbit));
      for (uint32_t i = 0; i < nbit; i++) {
        bool bbit = false;
        JXL_RETURN_IF_ERROR(visitor->Bool(false, &bbit));
        padding_bits.push_back(bbit);
      }
    } else {
      for (uint8_t& bit : padding_bits) {
        bool bbit = bit;
        JXL_RETURN_IF_ERROR(visitor->Bool(false, &bbit));
        bit = bbit;
      }
    }
  }

  {
    size_t dht_index = 0;
    size_t scan_index = 0;
    bool is_progressive = false;
    bool ac_ok[kMaxHuffmanTables] = {false};
    bool dc_ok[kMaxHuffmanTables] = {false};
    for (uint8_t marker : marker_order) {
      if (marker == 0xC2) {
        is_progressive = true;
      } else if (marker == 0xC4) {
        for (; dht_index < huffman_code.size();) {
          const JPEGHuffmanCode& huff = huffman_code[dht_index++];
          size_t index = huff.slot_id;
          if (index & 0x10) {
            index -= 0x10;
            ac_ok[index] = true;
          } else {
            dc_ok[index] = true;
          }
          if (huff.is_last) break;
        }
      } else if (marker == 0xDA) {
        const JPEGScanInfo& si = scan_info[scan_index++];
        for (size_t i = 0; i < si.num_components; ++i) {
          const JPEGComponentScanInfo& csi = si.components[i];
          size_t dc_tbl_idx = csi.dc_tbl_idx;
          size_t ac_tbl_idx = csi.ac_tbl_idx;
          bool want_dc = !is_progressive || (si.Ss == 0);
          if (want_dc && !dc_ok[dc_tbl_idx]) {
            return JXL_FAILURE("DC Huffman table used before defined");
          }
          bool want_ac = !is_progressive || (si.Ss != 0) || (si.Se != 0);
          if (want_ac && !ac_ok[ac_tbl_idx]) {
            return JXL_FAILURE("AC Huffman table used before defined");
          }
        }
      }
    }
  }

  // Apply postponed actions.
  if (visitor->IsReading()) {
    tail_data.resize(tail_data_len);
    JXL_ASSERT(inter_marker_data_sizes.size() == info.num_intermarker);
    inter_marker_data.reserve(info.num_intermarker);
    for (size_t i = 0; i < info.num_intermarker; ++i) {
      inter_marker_data.emplace_back(inter_marker_data_sizes[i]);
    }
  }

  return true;
}

#endif  // JPEGXL_ENABLE_TRANSCODE_JPEG

void JPEGData::CalculateMcuSize(const JPEGScanInfo& scan, int* MCUs_per_row,
                                int* MCU_rows) const {
  const bool is_interleaved = (scan.num_components > 1);
  const JPEGComponent& base_component = components[scan.components[0].comp_idx];
  // h_group / v_group act as numerators for converting number of blocks to
  // number of MCU. In interleaved mode it is 1, so MCU is represented with
  // max_*_samp_factor blocks. In non-interleaved mode we choose numerator to
  // be the samping factor, consequently MCU is always represented with single
  // block.
  const int h_group = is_interleaved ? 1 : base_component.h_samp_factor;
  const int v_group = is_interleaved ? 1 : base_component.v_samp_factor;
  int max_h_samp_factor = 1;
  int max_v_samp_factor = 1;
  for (const auto& c : components) {
    max_h_samp_factor = std::max(c.h_samp_factor, max_h_samp_factor);
    max_v_samp_factor = std::max(c.v_samp_factor, max_v_samp_factor);
  }
  *MCUs_per_row = DivCeil(width * h_group, 8 * max_h_samp_factor);
  *MCU_rows = DivCeil(height * v_group, 8 * max_v_samp_factor);
}

#if JPEGXL_ENABLE_TRANSCODE_JPEG

Status SetJPEGDataFromICC(const PaddedBytes& icc, jpeg::JPEGData* jpeg_data) {
  size_t icc_pos = 0;
  for (size_t i = 0; i < jpeg_data->app_data.size(); i++) {
    if (jpeg_data->app_marker_type[i] != jpeg::AppMarkerType::kICC) {
      continue;
    }
    size_t len = jpeg_data->app_data[i].size() - 17;
    if (icc_pos + len > icc.size()) {
      return JXL_FAILURE(
          "ICC length is less than APP markers: requested %" PRIuS
          " more bytes, "
          "%" PRIuS " available",
          len, icc.size() - icc_pos);
    }
    memcpy(&jpeg_data->app_data[i][17], icc.data() + icc_pos, len);
    icc_pos += len;
  }
  if (icc_pos != icc.size() && icc_pos != 0) {
    return JXL_FAILURE("ICC length is more than APP markers");
  }
  return true;
}

#endif  // JPEGXL_ENABLE_TRANSCODE_JPEG

}  // namespace jpeg
}  // namespace jxl
