//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/port/sleep.h"

#include <atomic>
#include <memory>

namespace td {

class SpinLock {
  struct Unlock {
    void operator()(SpinLock *ptr) {
      ptr->unlock();
    }
  };

  class InfBackoff {
    int cnt = 0;

   public:
    bool next() {
      cnt++;
      if (cnt < 50) {
        //TODO pause
        return true;
      } else {
        usleep_for(1);
        return true;
      }
    }
  };

 public:
  using Lock = std::unique_ptr<SpinLock, Unlock>;

  Lock lock() {
    InfBackoff backoff;
    while (!try_lock()) {
      backoff.next();
    }
    return Lock(this);
  }
  bool try_lock() {
    return !flag_.test_and_set(std::memory_order_acquire);
  }

 private:
  std::atomic_flag flag_ = ATOMIC_FLAG_INIT;
  void unlock() {
    flag_.clear(std::memory_order_release);
  }
};

}  // namespace td
