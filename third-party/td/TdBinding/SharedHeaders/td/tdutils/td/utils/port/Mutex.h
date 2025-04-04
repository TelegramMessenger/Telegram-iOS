//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include <mutex>

namespace td {

class Mutex {
 public:
  struct Guard {
    std::unique_lock<std::mutex> guard;
    void reset() {
      guard.unlock();
    }
  };

  Guard lock() {
    return {std::unique_lock<std::mutex>(mutex_)};
  }

 private:
  std::mutex mutex_;
};

}  // namespace td
