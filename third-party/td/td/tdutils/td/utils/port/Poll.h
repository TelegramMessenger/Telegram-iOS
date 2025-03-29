//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/port/config.h"

#include "td/utils/port/detail/Epoll.h"
#include "td/utils/port/detail/KQueue.h"
#include "td/utils/port/detail/Poll.h"
#include "td/utils/port/detail/Select.h"
#include "td/utils/port/detail/WineventPoll.h"

namespace td {

// clang-format off

#if TD_POLL_EPOLL
  using Poll = detail::Epoll;
#elif TD_POLL_KQUEUE
  using Poll = detail::KQueue;
#elif TD_POLL_WINEVENT
  using Poll = detail::WineventPoll;
#elif TD_POLL_POLL
  using Poll = detail::Poll;
#elif TD_POLL_SELECT
  using Poll = detail::Select;
#endif

// clang-format on

}  // namespace td
