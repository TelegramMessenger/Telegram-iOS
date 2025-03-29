//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/FlatHashSet.h"
#include "td/utils/Random.h"
#include "td/utils/tests.h"
#include "td/utils/WaitFreeHashSet.h"

TEST(WaitFreeHashSet, stress_test) {
  td::Random::Xorshift128plus rnd(123);
  td::FlatHashSet<td::uint64> reference;
  td::WaitFreeHashSet<td::uint64> set;

  td::vector<td::RandomSteps::Step> steps;
  auto add_step = [&](td::uint32 weight, auto f) {
    steps.emplace_back(td::RandomSteps::Step{std::move(f), weight});
  };

  auto gen_key = [&] {
    return rnd() % 100000 + 1;
  };

  auto check = [&](bool check_size = false) {
    if (check_size) {
      ASSERT_EQ(reference.size(), set.calc_size());
    }
    ASSERT_EQ(reference.empty(), set.empty());

    if (reference.size() < 100) {
      td::uint64 result = 0;
      for (auto &it : reference) {
        result += it * 101;
      }
      set.foreach([&](const td::uint64 &key) { result -= key * 101; });
      ASSERT_EQ(0u, result);
    }
  };

  add_step(2000, [&] {
    auto key = gen_key();
    ASSERT_EQ(reference.count(key), set.count(key));
    reference.insert(key);
    set.insert(key);
    ASSERT_EQ(reference.count(key), set.count(key));
    check();
  });

  add_step(500, [&] {
    auto key = gen_key();
    size_t reference_erased_count = reference.erase(key);
    size_t set_erased_count = set.erase(key);
    ASSERT_EQ(reference_erased_count, set_erased_count);
    check();
  });

  td::RandomSteps runner(std::move(steps));
  for (size_t i = 0; i < 1000000; i++) {
    runner.step(rnd);
  }

  for (size_t test = 0; test < 1000; test++) {
    reference = {};
    set = {};

    for (size_t i = 0; i < 100; i++) {
      runner.step(rnd);
    }
  }
}
