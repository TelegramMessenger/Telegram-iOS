//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/port/sleep.h"
#include "td/utils/type_traits.h"

#include <atomic>
#include <cstring>
#include <memory>

namespace td {

template <class T>
class AtomicRead {
 public:
  void read(T &dest) const {
    uint32 counter = 0;
    auto wait = [&] {
      counter++;
      const int wait_each_count = 4;
      if (counter % wait_each_count == 0) {
        usleep_for(1);
      }
    };

    while (true) {
      static_assert(TD_IS_TRIVIALLY_COPYABLE(T), "T must be trivially copyable");
      auto version_before = version.load();
      if (version_before % 2 == 0) {
        std::memcpy(&dest, &value, sizeof(dest));
        auto version_after = version.load();
        if (version_before == version_after) {
          break;
        }
      }
      wait();
    }
  }

  struct Write {
    explicit Write(AtomicRead *read) {
      read->do_lock();
      ptr.reset(read);
    }
    struct Destructor {
      void operator()(AtomicRead *read) const {
        read->do_unlock();
      }
    };
    T &operator*() {
      return value();
    }
    T *operator->() {
      return &value();
    }
    T &value() {
      CHECK(ptr);
      return ptr->value;
    }

   private:
    std::unique_ptr<AtomicRead, Destructor> ptr;
  };

  Write lock() {
    return Write(this);
  }

 private:
  std::atomic<uint64> version{0};
  T value;

  void do_lock() {
    bool is_locked = ++version % 2 == 1;
    CHECK(is_locked);
  }
  void do_unlock() {
    bool is_unlocked = ++version % 2 == 0;
    CHECK(is_unlocked);
  }
};

}  // namespace td
