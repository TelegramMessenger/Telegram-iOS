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

#include "td/utils/port/detail/ThreadPthread.h"
#include "td/utils/port/detail/ThreadStl.h"

namespace td {

// clang-format off

#if TD_THREAD_PTHREAD
  using thread = detail::ThreadPthread;
  namespace this_thread = detail::this_thread_pthread;
#elif TD_THREAD_STL
  using thread = detail::ThreadStl;
  namespace this_thread = detail::this_thread_stl;
#elif TD_THREAD_UNSUPPORTED
  namespace this_thread {
    inline void yield() {}
  }
#else
  #error "Thread's implementation is not defined"
#endif

// clang-format on

}  // namespace td
