//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/PollFlags.h"

namespace td {
class PollBase {
 public:
  PollBase() = default;
  PollBase(const PollBase &) = delete;
  PollBase &operator=(const PollBase &) = delete;
  PollBase(PollBase &&) = default;
  PollBase &operator=(PollBase &&) = default;
  virtual ~PollBase() = default;
  virtual void init() = 0;
  virtual void clear() = 0;
  virtual void subscribe(PollableFd fd, PollFlags flags) = 0;
  virtual void unsubscribe(PollableFdRef fd) = 0;
  virtual void unsubscribe_before_close(PollableFdRef fd) = 0;
  virtual void run(int timeout_ms) = 0;
};
}  // namespace td
