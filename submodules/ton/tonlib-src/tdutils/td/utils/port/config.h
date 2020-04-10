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

#include "td/utils/port/platform.h"

// clang-format off

#if TD_WINDOWS
  #define TD_PORT_WINDOWS 1
#else
  #define TD_PORT_POSIX 1
#endif

#if TD_LINUX || TD_ANDROID || TD_TIZEN
  #define TD_POLL_EPOLL 1
  #define TD_EVENTFD_LINUX 1
#elif TD_FREEBSD || TD_OPENBSD || TD_NETBSD
  #define TD_POLL_KQUEUE 1
  #define TD_EVENTFD_BSD 1
#elif TD_CYGWIN
  #define TD_POLL_SELECT 1
  #define TD_EVENTFD_BSD 1
#elif TD_EMSCRIPTEN
  #define TD_POLL_POLL 1
  #define TD_EVENTFD_UNSUPPORTED 1
#elif TD_DARWIN
  #define TD_POLL_KQUEUE 1
  #define TD_EVENTFD_BSD 1
#elif TD_WINDOWS
  #define TD_POLL_WINEVENT 1
  #define TD_EVENTFD_WINDOWS 1
#else
  #error "Poll's implementation is not defined"
#endif

#if TD_EMSCRIPTEN
  #define TD_THREAD_UNSUPPORTED 1
#elif TD_TIZEN || TD_LINUX || TD_DARWIN
  #define TD_THREAD_PTHREAD 1
#else
  #define TD_THREAD_STL 1
#endif

#if TD_LINUX
  #define TD_HAS_MMSG 1
#endif

// clang-format on
