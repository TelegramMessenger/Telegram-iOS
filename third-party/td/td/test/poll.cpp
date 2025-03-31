//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/PollManager.h"

#include "td/utils/logging.h"
#include "td/utils/tests.h"

static void check_vote_percentage(const std::vector<td::int32> &voter_counts, td::int32 total_count,
                                  const std::vector<td::int32> &expected) {
  auto result = td::PollManager::get_vote_percentage(voter_counts, total_count);
  if (result != expected) {
    LOG(FATAL) << "Have " << voter_counts << " and " << total_count << ", but received " << result << " instead of "
               << expected;
  }
}

TEST(Poll, get_vote_percentage) {
  check_vote_percentage({1}, 1, {100});
  check_vote_percentage({999}, 999, {100});
  check_vote_percentage({0}, 0, {0});
  check_vote_percentage({2, 1}, 3, {67, 33});
  check_vote_percentage({4, 1, 1}, 6, {66, 17, 17});
  check_vote_percentage({100, 100}, 200, {50, 50});
  check_vote_percentage({101, 99}, 200, {50, 50});
  check_vote_percentage({102, 98}, 200, {51, 49});
  check_vote_percentage({198, 2}, 200, {99, 1});
  check_vote_percentage({199, 1}, 200, {99, 1});
  check_vote_percentage({200}, 200, {100});
  check_vote_percentage({0, 999}, 999, {0, 100});
  check_vote_percentage({999, 999}, 999, {100, 100});
  check_vote_percentage({499, 599}, 999, {50, 60});
  check_vote_percentage({1, 1}, 2, {50, 50});
  check_vote_percentage({1, 1, 1}, 3, {33, 33, 33});
  check_vote_percentage({1, 1, 1, 1}, 4, {25, 25, 25, 25});
  check_vote_percentage({1, 1, 1, 1, 1}, 5, {20, 20, 20, 20, 20});
  check_vote_percentage({1, 1, 1, 1, 1, 1}, 6, {16, 16, 16, 16, 16, 16});
  check_vote_percentage({1, 1, 1, 1, 1, 1, 1}, 7, {14, 14, 14, 14, 14, 14, 14});
  check_vote_percentage({1, 1, 1, 1, 1, 1, 1, 1}, 8, {12, 12, 12, 12, 12, 12, 12, 12});
  check_vote_percentage({1, 1, 1, 1, 1, 1, 1, 1, 1}, 9, {11, 11, 11, 11, 11, 11, 11, 11, 11});
  check_vote_percentage({1, 1, 1, 1, 1, 1, 2}, 8, {12, 12, 12, 12, 12, 12, 25});
  check_vote_percentage({1, 1, 1, 2, 2, 2, 3}, 12, {8, 8, 8, 17, 17, 17, 25});
  check_vote_percentage({0, 1, 1, 1, 2, 2, 2, 3}, 12, {0, 8, 8, 8, 17, 17, 17, 25});
  check_vote_percentage({1, 1, 1, 0}, 3, {33, 33, 33, 0});
  check_vote_percentage({0, 1, 1, 1}, 3, {0, 33, 33, 33});
  check_vote_percentage({9949, 9950, 9999}, 10000, {99, 100, 100});
  check_vote_percentage({1234, 2345, 3456, 2841}, 9876,
                        {12 /* 12.49 */, 24 /* 23.74 */, 35 /* 34.99 */, 29 /* 28.76 */});
  check_vote_percentage({1234, 2301, 3500, 2841}, 9876,
                        {12 /* 12.49 */, 23 /* 23.29 */, 35 /* 35.43 */, 29 /* 28.76 */});
  check_vote_percentage({200, 200, 200, 270, 270, 60}, 1200, {17, 17, 17, 22, 22, 5});
  check_vote_percentage({200, 200, 200, 300, 240, 60}, 1200, {16, 16, 16, 25, 20, 5});
  check_vote_percentage({200, 200, 200, 250, 250, 20}, 1120, {18, 18, 18, 22, 22, 2});
  check_vote_percentage({200, 200, 200, 250, 250, 40}, 1140, {17, 17, 17, 22, 22, 4});
}
