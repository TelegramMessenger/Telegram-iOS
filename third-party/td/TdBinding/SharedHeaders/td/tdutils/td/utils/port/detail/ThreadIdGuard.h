//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

namespace td {
namespace detail {
class ThreadIdGuard {
 public:
  ThreadIdGuard();
  ~ThreadIdGuard();
  ThreadIdGuard(const ThreadIdGuard &) = delete;
  ThreadIdGuard &operator=(const ThreadIdGuard &) = delete;
  ThreadIdGuard(ThreadIdGuard &&) = delete;
  ThreadIdGuard &operator=(ThreadIdGuard &&) = delete;

 private:
  int32 thread_id_;
};
}  // namespace detail
}  // namespace td
