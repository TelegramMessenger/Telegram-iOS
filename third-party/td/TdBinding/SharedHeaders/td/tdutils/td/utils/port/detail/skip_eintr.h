//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#if TD_PORT_POSIX
#include "td/utils/common.h"
#include "td/utils/Time.h"

#include <cerrno>
#include <type_traits>
#endif

namespace td {

#if TD_PORT_POSIX
namespace detail {
template <class F>
auto skip_eintr(F &&f) {
  decltype(f()) res;
  static_assert(std::is_integral<decltype(res)>::value, "integral type expected");
  do {
    errno = 0;  // just in case
    res = f();
  } while (res < 0 && errno == EINTR);
  return res;
}

template <class F>
auto skip_eintr_cstr(F &&f) {
  char *res;
  do {
    errno = 0;  // just in case
    res = f();
  } while (res == nullptr && errno == EINTR);
  return res;
}

template <class F>
auto skip_eintr_timeout(F &&f, int32 timeout_ms) {
  decltype(f(timeout_ms)) res;
  static_assert(std::is_integral<decltype(res)>::value, "integral type expected");

  auto start = Timestamp::now();
  auto left_timeout_ms = timeout_ms;
  while (true) {
    errno = 0;  // just in case
    res = f(left_timeout_ms);
    if (res >= 0 || errno != EINTR) {
      break;
    }
    left_timeout_ms =
        static_cast<int32>(td::max((start.at() - Timestamp::now().at()) * 1000 + timeout_ms + 1 - 1e-9, 0.0));
  }
  return res;
}
}  // namespace detail
#endif

}  // namespace td
