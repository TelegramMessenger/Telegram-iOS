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
