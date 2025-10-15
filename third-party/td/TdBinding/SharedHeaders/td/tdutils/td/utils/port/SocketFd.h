//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/port/config.h"

#include "td/utils/port/detail/NativeFd.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/IoSlice.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/Slice.h"
#include "td/utils/Span.h"
#include "td/utils/Status.h"

#include <memory>

namespace td {

namespace detail {
class SocketFdImpl;
class SocketFdImplDeleter {
 public:
  void operator()(SocketFdImpl *impl);
};
}  // namespace detail

class SocketFd {
 public:
  SocketFd();
  SocketFd(const SocketFd &) = delete;
  SocketFd &operator=(const SocketFd &) = delete;
  SocketFd(SocketFd &&) noexcept;
  SocketFd &operator=(SocketFd &&) noexcept;
  ~SocketFd();

  Result<uint32> maximize_snd_buffer(uint32 max_size = 0);
  Result<uint32> maximize_rcv_buffer(uint32 max_size = 0);

  static Result<SocketFd> open(const IPAddress &address) TD_WARN_UNUSED_RESULT;

  PollableFdInfo &get_poll_info();
  const PollableFdInfo &get_poll_info() const;

  Status get_pending_error() TD_WARN_UNUSED_RESULT;

  Result<size_t> write(Slice slice) TD_WARN_UNUSED_RESULT;
  Result<size_t> writev(Span<IoSlice> slices) TD_WARN_UNUSED_RESULT;
  Result<size_t> read(MutableSlice slice) TD_WARN_UNUSED_RESULT;

  const NativeFd &get_native_fd() const;
  static Result<SocketFd> from_native_fd(NativeFd fd);

  void close();
  bool empty() const;

 private:
  std::unique_ptr<detail::SocketFdImpl, detail::SocketFdImplDeleter> impl_;
  explicit SocketFd(unique_ptr<detail::SocketFdImpl> impl);
};

namespace detail {
#if TD_PORT_POSIX
Status get_socket_pending_error(const NativeFd &fd);
#elif TD_PORT_WINDOWS
Status get_socket_pending_error(const NativeFd &fd, WSAOVERLAPPED *overlapped, Status iocp_error);
#endif
}  // namespace detail

}  // namespace td
