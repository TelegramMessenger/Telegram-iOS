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

#define TD_DUMMY_CHECK(condition) ((void)(condition))

#define CHECK(condition)                                               \
  if (!(condition)) {                                                  \
    ::td::detail::process_check_error(#condition, __FILE__, __LINE__); \
  }

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
