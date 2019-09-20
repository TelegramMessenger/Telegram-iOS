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
#include "td/utils/port/detail/NativeFd.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"

#if TD_PORT_POSIX
#include <fcntl.h>
#include <unistd.h>
#endif

#if TD_FD_DEBUG
#include <mutex>
#include <set>
#endif

namespace td {

#if TD_FD_DEBUG
class FdSet {
 public:
  void on_create_fd(NativeFd::Fd fd) {
    CHECK(is_valid(fd));
    if (is_stdio(fd)) {
      return;
    }
    std::unique_lock<std::mutex> guard(mutex_);
    if (fds_.count(fd) >= 1) {
      LOG(FATAL) << "Create duplicated fd: " << fd;
    }
    fds_.insert(fd);
  }

  Status validate(NativeFd::Fd fd) {
    if (!is_valid(fd)) {
      return Status::Error(PSLICE() << "Invalid fd: " << fd);
    }
    if (is_stdio(fd)) {
      return Status::OK();
    }
    std::unique_lock<std::mutex> guard(mutex_);
    if (fds_.count(fd) != 1) {
      return Status::Error(PSLICE() << "Unknown fd: " << fd);
    }
    return Status::OK();
  }

  void on_close_fd(NativeFd::Fd fd) {
    CHECK(is_valid(fd));
    if (is_stdio(fd)) {
      return;
    }
    std::unique_lock<std::mutex> guard(mutex_);
    if (fds_.count(fd) != 1) {
      LOG(FATAL) << "Close unknown fd: " << fd;
    }
    fds_.erase(fd);
  }

 private:
  std::mutex mutex_;
  std::set<NativeFd::Fd> fds_;

  bool is_stdio(NativeFd::Fd fd) const {
#if TD_PORT_WINDOWS
#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP | WINAPI_PARTITION_SYSTEM)
    return fd == GetStdHandle(STD_INPUT_HANDLE) || fd == GetStdHandle(STD_OUTPUT_HANDLE) ||
           fd == GetStdHandle(STD_ERROR_HANDLE);
#else
    return false;
#endif
#else
    return fd >= 0 && fd <= 2;
#endif
  }

  bool is_valid(NativeFd::Fd fd) const {
#if TD_PORT_WINDOWS
    return fd != INVALID_HANDLE_VALUE;
#else
    return fd >= 0;
#endif
  }
};

namespace {
FdSet &get_fd_set() {
  static FdSet res;
  return res;
}
}  // namespace

#endif

Status NativeFd::validate() const {
#if TD_FD_DEBUG
  return get_fd_set().validate(fd_.get());
#else
  return Status::OK();
#endif
}

NativeFd::NativeFd(Fd fd) : fd_(fd) {
  VLOG(fd) << *this << " create";
#if TD_FD_DEBUG
  get_fd_set().on_create_fd(fd_.get());
#endif
}

NativeFd::NativeFd(Fd fd, bool nolog) : fd_(fd) {
#if TD_FD_DEBUG
  get_fd_set().on_create_fd(fd_.get());
#endif
}

#if TD_PORT_WINDOWS
NativeFd::NativeFd(Socket socket) : fd_(reinterpret_cast<Fd>(socket)), is_socket_(true) {
  VLOG(fd) << *this << " create";
#if TD_FD_DEBUG
  get_fd_set().on_create_fd(fd_.get());
#endif
}
#endif

NativeFd &NativeFd::operator=(NativeFd &&from) {
  CHECK(this != &from);
  close();
  fd_ = std::move(from.fd_);
#if TD_PORT_WINDOWS
  is_socket_ = from.is_socket_;
#endif
  return *this;
}

NativeFd::~NativeFd() {
  close();
}

NativeFd::operator bool() const {
  return fd_.get() != empty_fd();
}

NativeFd::Fd NativeFd::empty_fd() {
#if TD_PORT_POSIX
  return -1;
#elif TD_PORT_WINDOWS
  return INVALID_HANDLE_VALUE;
#endif
}

NativeFd::Fd NativeFd::fd() const {
  return fd_.get();
}

NativeFd::Socket NativeFd::socket() const {
#if TD_PORT_POSIX
  return fd();
#elif TD_PORT_WINDOWS
  CHECK(is_socket_);
  return reinterpret_cast<Socket>(fd_.get());
#endif
}

Status NativeFd::set_is_blocking(bool is_blocking) const {
#if TD_PORT_POSIX
  auto old_flags = fcntl(fd(), F_GETFL);
  if (old_flags == -1) {
    return OS_SOCKET_ERROR("Failed to get socket flags");
  }
  auto new_flags = is_blocking ? old_flags & ~O_NONBLOCK : old_flags | O_NONBLOCK;
  if (new_flags != old_flags && fcntl(fd(), F_SETFL, new_flags) == -1) {
    return OS_SOCKET_ERROR("Failed to set socket flags");
  }

  return Status::OK();
#elif TD_PORT_WINDOWS
  return set_is_blocking_unsafe(is_blocking);
#endif
}

Status NativeFd::set_is_blocking_unsafe(bool is_blocking) const {
#if TD_PORT_POSIX
  if (fcntl(fd(), F_SETFL, is_blocking ? 0 : O_NONBLOCK) == -1) {
#elif TD_PORT_WINDOWS
  u_long mode = is_blocking;
  if (ioctlsocket(socket(), FIONBIO, &mode) != 0) {
#endif
    return OS_SOCKET_ERROR("Failed to change socket flags");
  }
  return Status::OK();
}

Status NativeFd::duplicate(const NativeFd &to) const {
#if TD_PORT_POSIX
  CHECK(*this);
  CHECK(to);
  if (dup2(fd(), to.fd()) == -1) {
    return OS_ERROR("Failed to duplicate file descriptor");
  }
  return Status::OK();
#elif TD_PORT_WINDOWS
  return Status::Error("Not supported");
#endif
}

void NativeFd::close() {
  if (!*this) {
    return;
  }

#if TD_FD_DEBUG
  get_fd_set().on_close_fd(fd());
#endif

  VLOG(fd) << *this << " close";
#if TD_PORT_WINDOWS
  if (is_socket_ ? closesocket(socket()) : !CloseHandle(fd())) {
#elif TD_PORT_POSIX
  if (::close(fd()) < 0) {
#endif
    auto error = OS_ERROR("Close fd");
    LOG(ERROR) << error;
  }
  fd_ = {};
}

NativeFd::Fd NativeFd::release() {
  VLOG(fd) << *this << " release";
  auto res = fd_.get();
  fd_ = {};
#if TD_FD_DEBUG
  get_fd_set().on_close_fd(res);
#endif
  return res;
}

StringBuilder &operator<<(StringBuilder &sb, const NativeFd &fd) {
  return sb << tag("fd", fd.fd());
}

}  // namespace td
