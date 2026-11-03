//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/port/config.h"

// include all and let config.h decide
#include "td/utils/port/detail/EventFdBsd.h"
#include "td/utils/port/detail/EventFdLinux.h"
#include "td/utils/port/detail/EventFdWindows.h"

namespace td {

// clang-format off

#if TD_EVENTFD_LINUX
  using EventFd = detail::EventFdLinux;
#elif TD_EVENTFD_BSD
  using EventFd = detail::EventFdBsd;
#elif TD_EVENTFD_WINDOWS
  using EventFd = detail::EventFdWindows;
#elif TD_EVENTFD_UNSUPPORTED
#else
  #error "EventFd's implementation is not defined"
#endif

// clang-format on

}  // namespace td
