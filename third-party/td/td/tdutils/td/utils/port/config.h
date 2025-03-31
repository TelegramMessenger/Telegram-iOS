//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
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
#elif TD_ILLUMOS
  #define TD_POLL_EPOLL 1
  #define TD_EVENTFD_LINUX 1
#elif TD_SOLARIS
  #define TD_POLL_POLL 1
  #define TD_EVENTFD_BSD 1
#else
  #error "Poll's implementation is not defined"
#endif

#if TD_EMSCRIPTEN
  #define TD_THREAD_UNSUPPORTED 1
#elif TD_WINDOWS
  #define TD_THREAD_STL 1
#else
  #define TD_THREAD_PTHREAD 1
#endif

#if TD_LINUX
  #define TD_HAS_MMSG 1
#endif

// clang-format on
