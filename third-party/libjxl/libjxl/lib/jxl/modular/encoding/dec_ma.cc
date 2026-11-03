// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/modular/encoding/dec_ma.h"

#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/dec_ans.h"
#include "lib/jxl/modular/encoding/ma_common.h"
#include "lib/jxl/modular/modular_image.h"

namespace jxl {

namespace {

Status ValidateTree(
    const Tree &tree,
    const std::vector<std::pair<pixel_type, pixel_type>> &prop_bounds,
    size_t root) {
  if (tree[root].property == -1) return true;
  size_t p = tree[root].property;
  int val = tree[root].splitval;
  if (prop_bounds[p].first > val) return JXL_FAILURE("Invalid tree");
  // Splitting at max value makes no sense: left range will be exactly same
  // as parent, right range will be invalid (min > max).
  if (prop_bounds[p].second <= val) return JXL_FAILURE("Invalid tree");
  auto new_bounds = prop_bounds;
  new_bounds[p].first = val + 1;
  JXL_RETURN_IF_ERROR(ValidateTree(tree, new_bounds, tree[root].lchild));
  new_bounds[p] = prop_bounds[p];
  new_bounds[p].second = val;
  return ValidateTree(tree, new_bounds, tree[root].rchild);
}

Status DecodeTree(BitReader *br, ANSSymbolReader *reader,
                  const std::vector<uint8_t> &context_map, Tree *tree,
                  size_t tree_size_limit) {
  size_t leaf_id = 0;
  size_t to_decode = 1;
  tree->clear();
  while (to_decode > 0) {
    JXL_RETURN_IF_ERROR(br->AllReadsWithinBounds());
    if (tree->size() > tree_size_limit) {
      return JXL_FAILURE("Tree is too large: %" PRIuS " nodes vs %" PRIuS
                         " max nodes",
                         tree->size(), tree_size_limit);
    }
    to_decode--;
    uint32_t prop1 = reader->ReadHybridUint(kPropertyContext, br, context_map);
    if (prop1 > 256) return JXL_FAILURE("Invalid tree property value");
    int property = prop1 - 1;
    if (property == -1) {
      size_t predictor =
          reader->ReadHybridUint(kPredictorContext, br, context_map);
      if (predictor >= kNumModularPredictors) {
        return JXL_FAILURE("Invalid predictor");
      }
      int64_t predictor_offset =
          UnpackSigned(reader->ReadHybridUint(kOffsetContext, br, context_map));
      uint32_t mul_log =
          reader->ReadHybridUint(kMultiplierLogContext, br, context_map);
      if (mul_log >= 31) {
        return JXL_FAILURE("Invalid multiplier logarithm");
      }
      uint32_t mul_bits =
          reader->ReadHybridUint(kMultiplierBitsContext, br, context_map);
      if (mul_bits + 1 >= 1u << (31u - mul_log)) {
        return JXL_FAILURE("Invalid multiplier");
      }
      uint32_t multiplier = (mul_bits + 1U) << mul_log;
      tree->emplace_back(-1, 0, leaf_id++, 0, static_cast<Predictor>(predictor),
                         predictor_offset, multiplier);
      continue;
    }
    int splitval =
        UnpackSigned(reader->ReadHybridUint(kSplitValContext, br, context_map));
    tree->emplace_back(property, splitval, tree->size() + to_decode + 1,
                       tree->size() + to_decode + 2, Predictor::Zero, 0, 1);
    to_decode += 2;
  }
  std::vector<std::pair<pixel_type, pixel_type>> prop_bounds;
  prop_bounds.resize(256, {std::numeric_limits<pixel_type>::min(),
                           std::numeric_limits<pixel_type>::max()});
  return ValidateTree(*tree, prop_bounds, 0);
}
}  // namespace

Status DecodeTree(BitReader *br, Tree *tree, size_t tree_size_limit) {
  std::vector<uint8_t> tree_context_map;
  ANSCode tree_code;
  JXL_RETURN_IF_ERROR(
      DecodeHistograms(br, kNumTreeContexts, &tree_code, &tree_context_map));
  // TODO(eustas): investigate more infinite tree cases.
  if (tree_code.degenerate_symbols[tree_context_map[kPropertyContext]] > 0) {
    return JXL_FAILURE("Infinite tree");
  }
  ANSSymbolReader reader(&tree_code, br);
  JXL_RETURN_IF_ERROR(DecodeTree(br, &reader, tree_context_map, tree,
                                 std::min(tree_size_limit, kMaxTreeSize)));
  if (!reader.CheckANSFinalState()) {
    return JXL_FAILURE("ANS decode final state failed");
  }
  return true;
}

}  // namespace jxl
