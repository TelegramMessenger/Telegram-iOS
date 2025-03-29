//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/ExitGuard.h"

#include "td/utils/logging.h"

namespace td {

std::atomic<bool> ExitGuard::is_exited_{false};

ExitGuard::~ExitGuard() {
  is_exited_.store(true, std::memory_order_relaxed);
  set_verbosity_level(VERBOSITY_NAME(FATAL));
}

}  // namespace td
