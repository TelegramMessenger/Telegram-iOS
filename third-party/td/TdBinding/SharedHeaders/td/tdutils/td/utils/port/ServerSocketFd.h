//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
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
  ServerSocketFd(ServerSocketFd &&) noexcept;
  ServerSocketFd &operator=(ServerSocketFd &&) noexcept;
  ~ServerSocketFd();

  Result<uint32> maximize_snd_buffer(uint32 max_size = 0);
  Result<uint32> maximize_rcv_buffer(uint32 max_size = 0);

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
