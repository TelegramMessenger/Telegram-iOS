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
