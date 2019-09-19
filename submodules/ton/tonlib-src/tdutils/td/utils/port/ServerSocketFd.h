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

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "td/utils/port/detail/NativeFd.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/SocketFd.h"

#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <memory>

namespace td {
namespace detail {
class ServerSocketFdImpl;
class ServerSocketFdImplDeleter {
 public:
  void operator()(ServerSocketFdImpl *impl);
};
}  // namespace detail

class ServerSocketFd {
 public:
  ServerSocketFd();
  ServerSocketFd(const ServerSocketFd &) = delete;
  ServerSocketFd &operator=(const ServerSocketFd &) = delete;
  ServerSocketFd(ServerSocketFd &&);
  ServerSocketFd &operator=(ServerSocketFd &&);
  ~ServerSocketFd();

  static Result<ServerSocketFd> open(int32 port, CSlice addr = CSlice("0.0.0.0")) TD_WARN_UNUSED_RESULT;

  PollableFdInfo &get_poll_info();
  const PollableFdInfo &get_poll_info() const;

  Status get_pending_error() TD_WARN_UNUSED_RESULT;

  Result<SocketFd> accept() TD_WARN_UNUSED_RESULT;

  void close();
  bool empty() const;

  const NativeFd &get_native_fd() const;

 private:
  std::unique_ptr<detail::ServerSocketFdImpl, detail::ServerSocketFdImplDeleter> impl_;
  explicit ServerSocketFd(unique_ptr<detail::ServerSocketFdImpl> impl);
};
}  // namespace td
