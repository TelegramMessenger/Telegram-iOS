//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/FloodControlGlobal.h"

namespace td {

FloodControlGlobal::FloodControlGlobal(uint64 limit) : limit_(limit) {
}

void FloodControlGlobal::finish() {
  auto old_value = active_count_.fetch_sub(1, std::memory_order_relaxed);
  CHECK(old_value > 0);
}

FloodControlGlobal::Guard FloodControlGlobal::try_start() {
  auto old_value = active_count_.fetch_add(1, std::memory_order_relaxed);
  if (old_value >= limit_) {
    finish();
    return nullptr;
  }
  return Guard(this);
}

void FloodControlGlobal::Finish::operator()(FloodControlGlobal *ctrl) const {
  ctrl->finish();
}

}  // namespace td
