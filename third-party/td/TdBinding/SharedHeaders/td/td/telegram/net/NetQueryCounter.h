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

class NetQueryCounter {
 public:
  using Counter = std::atomic<uint64>;

  NetQueryCounter() = default;

  explicit NetQueryCounter(Counter *counter) : ptr_(counter) {
    CHECK(counter != nullptr);
    counter->fetch_add(1, std::memory_order_relaxed);
  }

  explicit operator bool() const noexcept {
    return static_cast<bool>(ptr_);
  }

 private:
  struct Deleter {
    void operator()(Counter *ptr) {
      ptr->fetch_sub(1, std::memory_order_relaxed);
    }
  };
  std::unique_ptr<Counter, Deleter> ptr_;
};

}  // namespace td
