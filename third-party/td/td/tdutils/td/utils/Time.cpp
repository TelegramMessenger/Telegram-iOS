//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/Time.h"

#include "td/utils/port/Clocks.h"

#include <atomic>
#include <cmath>

namespace td {

bool operator==(Timestamp a, Timestamp b) {
  return std::abs(a.at() - b.at()) < 1e-6;
}

static std::atomic<double> time_diff;

double Time::now() {
  auto result = now_unadjusted() + time_diff.load(std::memory_order_relaxed);
  while (result < 0) {
    auto old_time_diff = time_diff.load();
    time_diff.compare_exchange_strong(old_time_diff, old_time_diff - result);
    result = now_unadjusted() + time_diff.load(std::memory_order_relaxed);
  }
  return result;
}

double Time::now_unadjusted() {
  return Clocks::monotonic();
}

void Time::jump_in_future(double at) {
  while (true) {
    auto old_time_diff = time_diff.load();
    auto diff = at - now();
    if (diff < 0) {
      return;
    }
    if (time_diff.compare_exchange_strong(old_time_diff, old_time_diff + diff)) {
      return;
    }
  }
}

}  // namespace td
