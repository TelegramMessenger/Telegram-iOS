//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/detail/NativeFd.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/SliceBuilder.h"

#if TD_PORT_POSIX
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#endif

#if TD_FD_DEBUG
#include <mutex>
#include <set>
#endif

namespace td {

int VERBOSITY_NAME(fd) = VERBOSITY_NAME(DEBUG) + 9;

#if TD_FD_DEBUG
class FdSet {
 public:
  void on_create_fd(NativeFd::Fd fd) {
    if (!is_valid(fd)) {
      return;
    }
    if (is_stdio(fd)) {
      return;
    }
    std::unique_lock<std::mutex> guard(mutex_);
    if (fds_.count(fd) >= 1) {
      LOG(FATAL) << "Create duplicate fd: " << fd;
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
    if (!is_valid(fd)) {
      return;
    }
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
  return get_fd_set().validate(fd_);
#else
  return Status::OK();
#endif
}

NativeFd::NativeFd(Fd fd) : fd_(fd) {
  VLOG(fd) << *this << " create";
#if TD_FD_DEBUG
  get_fd_set().on_create_fd(fd_);
#endif
}

NativeFd::NativeFd(Fd fd, bool nolog) : fd_(fd) {
#if TD_FD_DEBUG
  get_fd_set().on_create_fd(fd_);
#endif
}

#if TD_PORT_WINDOWS
NativeFd::NativeFd(Socket socket) : fd_(reinterpret_cast<Fd>(socket)), is_socket_(true) {
  VLOG(fd) << *this << " create";
#if TD_FD_DEBUG
  get_fd_set().on_create_fd(fd_);
#endif
}
#endif

NativeFd::NativeFd(NativeFd &&other) noexcept : fd_(other.fd_) {
#if TD_PORT_WINDOWS
  is_socket_ = other.is_socket_;
#endif
  other.fd_ = empty_fd();
}

NativeFd &NativeFd::operator=(NativeFd &&other) noexcept {
  CHECK(this != &other);
  close();
  fd_ = other.fd_;
#if TD_PORT_WINDOWS
  is_socket_ = other.is_socket_;
#endif
  other.fd_ = empty_fd();
  return *this;
}

NativeFd::~NativeFd() {
  close();
}

NativeFd::operator bool() const noexcept {
  return fd_ != empty_fd();
}

NativeFd::Fd NativeFd::empty_fd() {
#if TD_PORT_POSIX
  return -1;
#elif TD_PORT_WINDOWS
  return INVALID_HANDLE_VALUE;
#endif
}

NativeFd::Fd NativeFd::fd() const {
  return fd_;
}

NativeFd::Socket NativeFd::socket() const {
#if TD_PORT_POSIX
  return fd();
#elif TD_PORT_WINDOWS
  CHECK(is_socket_);
  return reinterpret_cast<Socket>(fd_);
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

static Result<uint32> maximize_buffer(const NativeFd::Socket &socket, int optname, uint32 max_size) {
  if (setsockopt(socket, SOL_SOCKET, optname, reinterpret_cast<const char *>(&max_size), sizeof(max_size)) == 0) {
    // fast path
    return max_size;
  }

  /* Start with the default size. */
  uint32 old_size = 0;
  socklen_t intsize = sizeof(old_size);
  if (getsockopt(socket, SOL_SOCKET, optname, reinterpret_cast<char *>(&old_size), &intsize)) {
    return OS_SOCKET_ERROR("getsockopt() failed");
  }
#if TD_LINUX
  old_size /= 2;
#endif

  /* Binary-search for the real maximum. */
  uint32 last_good_size = old_size;
  uint32 min_size = old_size;
  while (min_size <= max_size) {
    uint32 avg_size = min_size + (max_size - min_size) / 2;
    if (setsockopt(socket, SOL_SOCKET, optname, reinterpret_cast<const char *>(&avg_size), sizeof(avg_size)) == 0) {
      last_good_size = avg_size;
      min_size = avg_size + 1;
    } else {
      max_size = avg_size - 1;
    }
  }
  return last_good_size;
}

Result<uint32> NativeFd::maximize_snd_buffer(uint32 max_size) const {
  return maximize_buffer(socket(), SO_SNDBUF, max_size == 0 ? DEFAULT_MAX_SND_BUFFER_SIZE : max_size);
}

Result<uint32> NativeFd::maximize_rcv_buffer(uint32 max_size) const {
  return maximize_buffer(socket(), SO_RCVBUF, max_size == 0 ? DEFAULT_MAX_RCV_BUFFER_SIZE : max_size);
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
  fd_ = empty_fd();
}

NativeFd::Fd NativeFd::release() {
  VLOG(fd) << *this << " release";
  auto res = fd_;
  fd_ = empty_fd();
#if TD_FD_DEBUG
  get_fd_set().on_close_fd(res);
#endif
  return res;
}

StringBuilder &operator<<(StringBuilder &sb, const NativeFd &fd) {
  return sb << tag("fd", fd.fd());
}

}  // namespace td
