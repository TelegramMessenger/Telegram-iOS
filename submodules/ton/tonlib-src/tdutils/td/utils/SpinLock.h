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

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "td/utils/port/thread.h"

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
        td::this_thread::yield();
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
