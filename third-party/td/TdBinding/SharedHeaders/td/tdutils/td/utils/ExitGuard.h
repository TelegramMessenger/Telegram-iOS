//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include <atomic>

namespace td {

class ExitGuard {
 public:
  ExitGuard() = default;
  ExitGuard(ExitGuard &&) = delete;
  ExitGuard &operator=(ExitGuard &&) = delete;
  ExitGuard(const ExitGuard &) = delete;
  ExitGuard &operator=(const ExitGuard &) = delete;
  ~ExitGuard();

  static bool is_exited() {
    return is_exited_.load(std::memory_order_relaxed);
  }

 private:
  static std::atomic<bool> is_exited_;
};

}  // namespace td
