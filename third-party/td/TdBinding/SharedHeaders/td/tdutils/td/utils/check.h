//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#define TD_DUMMY_CHECK(condition) ((void)(condition))

#define CHECK_IMPL(condition, file, line)                      \
  if (!(condition)) {                                          \
    ::td::detail::process_check_error(#condition, file, line); \
  }

#define CHECK(condition) CHECK_IMPL(condition, __FILE__, __LINE__)

// clang-format off
#ifdef NDEBUG
  #define DCHECK TD_DUMMY_CHECK
#else
  #define DCHECK CHECK
#endif
// clang-format on

#define UNREACHABLE() ::td::detail::process_check_error("Unreachable", __FILE__, __LINE__)

namespace td {
namespace detail {

[[noreturn]] void process_check_error(const char *message, const char *file, int line);

}  // namespace detail
}  // namespace td
