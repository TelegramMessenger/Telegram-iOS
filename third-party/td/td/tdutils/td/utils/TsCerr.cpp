//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/TsCerr.h"

#include "td/utils/ExitGuard.h"
#include "td/utils/port/StdStreams.h"
#include "td/utils/Time.h"

#include <cerrno>

namespace td {

std::atomic_flag TsCerr::lock_ = ATOMIC_FLAG_INIT;

TsCerr::TsCerr() {
  enterCritical();
}

TsCerr::~TsCerr() {
  exitCritical();
}

TsCerr &TsCerr::operator<<(Slice slice) {
  auto &fd = Stderr();
  if (fd.empty()) {
    return *this;
  }
  double end_time = 0;
  while (!slice.empty()) {
    auto res = fd.write(slice);
    if (res.is_error()) {
      if (res.error().code() == EPIPE) {
        break;
      }
      // Resource temporary unavailable
      if (end_time == 0) {
        end_time = Time::now() + 0.01;
      } else if (Time::now() > end_time) {
        break;
      }
      continue;
    }
    slice.remove_prefix(res.ok());
  }
  return *this;
}

void TsCerr::enterCritical() {
  while (lock_.test_and_set(std::memory_order_acquire) && !ExitGuard::is_exited()) {
    // spin
  }
}

void TsCerr::exitCritical() {
  lock_.clear(std::memory_order_release);
}

static ExitGuard exit_guard;

}  // namespace td
