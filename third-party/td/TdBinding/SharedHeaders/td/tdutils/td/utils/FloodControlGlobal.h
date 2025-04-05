//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

#include <atomic>
#include <memory>

namespace td {

// Restricts the total number of events
class FloodControlGlobal {
 public:
  explicit FloodControlGlobal(uint64 limit);

  struct Finish {
    void operator()(FloodControlGlobal *ctrl) const;
  };
  using Guard = std::unique_ptr<FloodControlGlobal, Finish>;

  Guard try_start();

 private:
  std::atomic<uint64> active_count_{0};
  uint64 limit_{0};

  void finish();
};

}  // namespace td
