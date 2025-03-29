//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/common.h"
#include "td/utils/Random.h"
#include "td/utils/tests.h"
#include "td/utils/WaitFreeVector.h"

TEST(WaitFreeVector, stress_test) {
  td::Random::Xorshift128plus rnd(123);
  td::vector<td::uint64> reference;
  td::WaitFreeVector<td::uint64> vector;

  td::vector<td::RandomSteps::Step> steps;
  auto add_step = [&](td::uint32 weight, auto f) {
    steps.emplace_back(td::RandomSteps::Step{std::move(f), weight});
  };

  auto gen_key = [&] {
    return static_cast<size_t>(rnd() % reference.size());
  };

  add_step(2000, [&] {
    ASSERT_EQ(reference.size(), vector.size());
    ASSERT_EQ(reference.empty(), vector.empty());
    if (reference.empty()) {
      return;
    }
    auto key = gen_key();
    ASSERT_EQ(reference[key], vector[key]);
    auto value = rnd();
    reference[key] = value;
    vector[key] = value;
    ASSERT_EQ(reference[key], vector[key]);
  });

  add_step(2000, [&] {
    ASSERT_EQ(reference.size(), vector.size());
    ASSERT_EQ(reference.empty(), vector.empty());
    auto value = rnd();
    reference.emplace_back(value);
    if (rnd() & 1) {
      vector.emplace_back(value);
    } else if (rnd() & 1) {
      vector.push_back(value);
    } else {
      vector.push_back(std::move(value));
    }
    ASSERT_EQ(reference.back(), vector.back());
  });

  add_step(500, [&] {
    ASSERT_EQ(reference.size(), vector.size());
    ASSERT_EQ(reference.empty(), vector.empty());
    if (reference.empty()) {
      return;
    }
    reference.pop_back();
    vector.pop_back();
  });

  td::RandomSteps runner(std::move(steps));
  for (size_t i = 0; i < 1000000; i++) {
    runner.step(rnd);
  }
}
