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

#include "td/utils/common.h"
#include "td/utils/MovableValue.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class NativeFd {
 public:
#if TD_PORT_POSIX
  using Fd = int;
  using Socket = int;
#elif TD_PORT_WINDOWS
  using Fd = HANDLE;
  using Socket = SOCKET;
#endif
  NativeFd() = default;
  NativeFd(NativeFd &&) = default;
  NativeFd &operator=(NativeFd &&);
  explicit NativeFd(Fd fd);
  NativeFd(Fd fd, bool nolog);
#if TD_PORT_WINDOWS
  explicit NativeFd(Socket socket);
#endif
  NativeFd(const NativeFd &) = delete;
  NativeFd &operator=(const NativeFd &) = delete;
  ~NativeFd();

  explicit operator bool() const;

  static Fd empty_fd();

  Fd fd() const;
  Socket socket() const;

  Status set_is_blocking(bool is_blocking) const;

  Status set_is_blocking_unsafe(bool is_blocking) const;  // may drop other Fd flags on non-Windows

  Status duplicate(const NativeFd &to) const;

  void close();
  Fd release();

  Status validate() const;

 private:
#if TD_PORT_POSIX
  MovableValue<Fd, -1> fd_;
#elif TD_PORT_WINDOWS
  MovableValue<Fd, INVALID_HANDLE_VALUE> fd_;
  bool is_socket_{false};
#endif
};

StringBuilder &operator<<(StringBuilder &sb, const NativeFd &fd);

}  // namespace td
