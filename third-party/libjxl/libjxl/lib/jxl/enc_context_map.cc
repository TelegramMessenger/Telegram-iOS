// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Library to encode the context map.

#include "lib/jxl/enc_context_map.h"

#include <stdint.h>

#include <algorithm>
#include <cstddef>
#include <vector>

#include "lib/jxl/base/bits.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/enc_ans.h"
#include "lib/jxl/enc_aux_out.h"
#include "lib/jxl/entropy_coder.h"

namespace jxl {

namespace {

size_t IndexOf(const std::vector<uint8_t>& v, uint8_t value) {
  size_t i = 0;
  for (; i < v.size(); ++i) {
    if (v[i] == value) return i;
  }
  return i;
}

void MoveToFront(std::vector<uint8_t>* v, size_t index) {
  uint8_t value = (*v)[index];
  for (size_t i = index; i != 0; --i) {
    (*v)[i] = (*v)[i - 1];
  }
  (*v)[0] = value;
}

std::vector<uint8_t> MoveToFrontTransform(const std::vector<uint8_t>& v) {
  if (v.empty()) return v;
  uint8_t max_value = *std::max_element(v.begin(), v.end());
  std::vector<uint8_t> mtf(max_value + 1);
  for (size_t i = 0; i <= max_value; ++i) mtf[i] = i;
  std::vector<uint8_t> result(v.size());
  for (size_t i = 0; i < v.size(); ++i) {
    size_t index = IndexOf(mtf, v[i]);
    JXL_ASSERT(index < mtf.size());
    result[i] = static_cast<uint8_t>(index);
    MoveToFront(&mtf, index);
  }
  return result;
}

}  // namespace

void EncodeContextMap(const std::vector<uint8_t>& context_map,
                      size_t num_histograms, BitWriter* writer, size_t layer,
                      AuxOut* aux_out) {
  if (num_histograms == 1) {
    // Simple code
    writer->Write(1, 1);
    // 0 bits per entry.
    writer->Write(2, 0);
    return;
  }

  std::vector<uint8_t> transformed_symbols = MoveToFrontTransform(context_map);
  std::vector<std::vector<Token>> tokens(1), mtf_tokens(1);
  EntropyEncodingData codes;
  std::vector<uint8_t> dummy_context_map;
  for (size_t i = 0; i < context_map.size(); i++) {
    tokens[0].emplace_back(0, context_map[i]);
  }
  for (size_t i = 0; i < transformed_symbols.size(); i++) {
    mtf_tokens[0].emplace_back(0, transformed_symbols[i]);
  }
  HistogramParams params;
  params.uint_method = HistogramParams::HybridUintMethod::kContextMap;
  size_t ans_cost = BuildAndEncodeHistograms(
      params, 1, tokens, &codes, &dummy_context_map, nullptr, 0, nullptr);
  size_t mtf_cost = BuildAndEncodeHistograms(
      params, 1, mtf_tokens, &codes, &dummy_context_map, nullptr, 0, nullptr);
  bool use_mtf = mtf_cost < ans_cost;
  // Rebuild token list.
  tokens[0].clear();
  for (size_t i = 0; i < transformed_symbols.size(); i++) {
    tokens[0].emplace_back(0,
                           use_mtf ? transformed_symbols[i] : context_map[i]);
  }
  size_t entry_bits = CeilLog2Nonzero(num_histograms);
  size_t simple_cost = entry_bits * context_map.size();
  if (entry_bits < 4 && simple_cost < ans_cost && simple_cost < mtf_cost) {
    writer->Write(1, 1);
    writer->Write(2, entry_bits);
    for (size_t i = 0; i < context_map.size(); i++) {
      writer->Write(entry_bits, context_map[i]);
    }
  } else {
    writer->Write(1, 0);
    writer->Write(1, use_mtf);  // Use/don't use MTF.
    BuildAndEncodeHistograms(params, 1, tokens, &codes, &dummy_context_map,
                             writer, layer, aux_out);
    WriteTokens(tokens[0], codes, dummy_context_map, writer);
  }
}

void EncodeBlockCtxMap(const BlockCtxMap& block_ctx_map, BitWriter* writer,
                       AuxOut* aux_out) {
  auto& dct = block_ctx_map.dc_thresholds;
  auto& qft = block_ctx_map.qf_thresholds;
  auto& ctx_map = block_ctx_map.ctx_map;
  BitWriter::Allotment allotment(
      writer,
      (dct[0].size() + dct[1].size() + dct[2].size() + qft.size()) * 34 + 1 +
          4 + 4 + ctx_map.size() * 10 + 1024);
  if (dct[0].empty() && dct[1].empty() && dct[2].empty() && qft.empty() &&
      ctx_map.size() == 21 &&
      std::equal(ctx_map.begin(), ctx_map.end(), BlockCtxMap::kDefaultCtxMap)) {
    writer->Write(1, 1);  // default
    allotment.ReclaimAndCharge(writer, kLayerAC, aux_out);
    return;
  }
  writer->Write(1, 0);
  for (int j : {0, 1, 2}) {
    writer->Write(4, dct[j].size());
    for (int i : dct[j]) {
      JXL_CHECK(U32Coder::Write(kDCThresholdDist, PackSigned(i), writer));
    }
  }
  writer->Write(4, qft.size());
  for (uint32_t i : qft) {
    JXL_CHECK(U32Coder::Write(kQFThresholdDist, i - 1, writer));
  }
  EncodeContextMap(ctx_map, block_ctx_map.num_ctxs, writer, kLayerAC, aux_out);
  allotment.ReclaimAndCharge(writer, kLayerAC, aux_out);
}

}  // namespace jxl
