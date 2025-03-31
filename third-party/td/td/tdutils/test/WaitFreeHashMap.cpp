//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/Random.h"
#include "td/utils/tests.h"
#include "td/utils/WaitFreeHashMap.h"

TEST(WaitFreeHashMap, stress_test) {
  td::Random::Xorshift128plus rnd(123);
  td::FlatHashMap<td::uint64, td::uint64> reference;
  td::WaitFreeHashMap<td::uint64, td::uint64> map;

  td::vector<td::RandomSteps::Step> steps;
  auto add_step = [&](td::uint32 weight, auto f) {
    steps.emplace_back(td::RandomSteps::Step{std::move(f), weight});
  };

  auto gen_key = [&] {
    return rnd() % 100000 + 1;
  };

  auto check = [&](bool check_size = false) {
    if (check_size) {
      ASSERT_EQ(reference.size(), map.calc_size());
    }
    ASSERT_EQ(reference.empty(), map.empty());

    if (reference.size() < 100) {
      td::uint64 result = 0;
      for (auto &it : reference) {
        result += it.first * 101;
        result += it.second;
      }
      map.foreach([&](const td::uint64 &key, td::uint64 &value) {
        result -= key * 101;
        result -= value;
      });
      ASSERT_EQ(0u, result);
    }
  };

  add_step(2000, [&] {
    auto key = gen_key();
    auto value = rnd();
    reference[key] = value;
    if (td::Random::fast_bool()) {
      map.set(key, value);
    } else {
      map[key] = value;
    }
    ASSERT_EQ(reference[key], map.get(key));
    check();
  });

  add_step(200, [&] {
    auto key = gen_key();
    ASSERT_EQ(reference[key], map[key]);
    check(true);
  });

  add_step(2000, [&] {
    auto key = gen_key();
    auto ref_it = reference.find(key);
    auto ref_value = ref_it == reference.end() ? 0 : ref_it->second;
    ASSERT_EQ(ref_value, map.get(key));
    check();
  });

  add_step(500, [&] {
    auto key = gen_key();
    size_t reference_erased_count = reference.erase(key);
    size_t map_erased_count = map.erase(key);
    ASSERT_EQ(reference_erased_count, map_erased_count);
    check();
  });

  td::RandomSteps runner(std::move(steps));
  for (size_t i = 0; i < 1000000; i++) {
    runner.step(rnd);
  }

  for (size_t test = 0; test < 1000; test++) {
    reference = {};
    map = {};

    for (size_t i = 0; i < 100; i++) {
      runner.step(rnd);
    }
  }
}
