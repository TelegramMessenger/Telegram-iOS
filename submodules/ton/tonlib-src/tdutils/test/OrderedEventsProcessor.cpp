/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
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
    auto shift = td::Random::fast(0, 1) ? td::Random::fast(0, d) : td::Random::fast(0, 1) * d;
    v.push_back({i + shift, i + offset});
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
