//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/OrderedEventsProcessor.h"
#include "td/utils/Random.h"
#include "td/utils/tests.h"

#include <algorithm>
#include <utility>
#include <vector>

TEST(OrderedEventsProcessor, random) {
  int d = 5001;
  int n = 1000000;
  int offset = 1000000;
  std::vector<std::pair<int, int>> v;
  for (int i = 0; i < n; i++) {
    auto shift = td::Random::fast_bool() ? td::Random::fast(0, d) : td::Random::fast(0, 1) * d;
    v.emplace_back(i + shift, i + offset);
  }
  std::sort(v.begin(), v.end());

  td::OrderedEventsProcessor<int> processor(offset);
  int next_pos = offset;
  for (auto p : v) {
    int seq_no = p.second;
    processor.add(seq_no, seq_no, [&](auto seq_no, int x) {
      ASSERT_EQ(x, next_pos);
      next_pos++;
    });
  }
  ASSERT_EQ(next_pos, n + offset);
}
