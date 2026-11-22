// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/ans_common.h"

#include <vector>

#include "lib/jxl/ans_params.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

void VerifyAliasDistribution(const std::vector<int>& distribution,
                             uint32_t range) {
  constexpr size_t log_alpha_size = 8;
  AliasTable::Entry table[1 << log_alpha_size];
  InitAliasTable(distribution, range, log_alpha_size, table);
  std::vector<std::vector<uint32_t>> offsets(distribution.size());
  for (uint32_t i = 0; i < range; i++) {
    AliasTable::Symbol s = AliasTable::Lookup(
        table, i, ANS_LOG_TAB_SIZE - 8, (1 << (ANS_LOG_TAB_SIZE - 8)) - 1);
    offsets[s.value].push_back(s.offset);
  }
  for (uint32_t i = 0; i < distribution.size(); i++) {
    ASSERT_EQ(static_cast<size_t>(distribution[i]), offsets[i].size());
    std::sort(offsets[i].begin(), offsets[i].end());
    for (uint32_t j = 0; j < offsets[i].size(); j++) {
      ASSERT_EQ(offsets[i][j], j);
    }
  }
}

TEST(ANSCommonTest, AliasDistributionSmoke) {
  VerifyAliasDistribution({ANS_TAB_SIZE / 2, ANS_TAB_SIZE / 2}, ANS_TAB_SIZE);
  VerifyAliasDistribution({ANS_TAB_SIZE}, ANS_TAB_SIZE);
  VerifyAliasDistribution({0, 0, 0, ANS_TAB_SIZE, 0}, ANS_TAB_SIZE);
}

}  // namespace
}  // namespace jxl
