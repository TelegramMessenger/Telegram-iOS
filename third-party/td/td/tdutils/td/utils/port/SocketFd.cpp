//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/SocketFd.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/detail/skip_eintr.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/SliceBuilder.h"

#if TD_PORT_WINDOWS
#include "td/utils/buffer.h"
#include "td/utils/port/detail/Iocp.h"
#include "td/utils/port/Mutex.h"
#include "td/utils/VectorQueue.h"

#include <limits>
#endif

#if TD_PORT_POSIX
#include <cerrno>

#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#endif

#include <atomic>
#include <cstring>

namespace td {
namespace detail {
#if TD_PORT_WINDOWS
class SocketFdImpl final : private Iocp::Callback {
 public:
  explicit SocketFdImpl(NativeFd native_fd) : info_(std::move(native_fd)) {
    VLOG(fd) << get_native_fd() << " create from native_fd";
    get_poll_info().add_flags(PollFlags::Write());
    Iocp::get()->subscribe(get_native_fd(), this);
    is_read_active_ = true;
    notify_iocp_connected();
  }

  SocketFdImpl(NativeFd native_fd, const IPAddress &addr) : info_(std::move(native_fd)) {
    VLOG(fd) << get_native_fd() << " create from native_fd and connect";
    get_poll_info().add_flags(PollFlags::Write());
    Iocp::get()->subscribe(get_native_fd(), this);
    LPFN_CONNECTEX ConnectExPtr = nullptr;
    GUID guid = WSAID_CONNECTEX;
    DWORD numBytes;
    auto error =
        ::WSAIoctl(get_native_fd().socket(), SIO_GET_EXTENSION_FUNCTION_POINTER, static_cast<void *>(&guid),
                   sizeof(guid), static_cast<void *>(&ConnectExPtr), sizeof(ConnectExPtr), &numBytes, nullptr, nullptr);
    if (error) {
      on_error(OS_SOCKET_ERROR("WSAIoctl failed"));
      return;
    }
    std::memset(&read_overlapped_, 0, sizeof(read_overlapped_));
    inc_refcnt();
    is_read_active_ = true;
    auto status = ConnectExPtr(get_native_fd().socket(), addr.get_sockaddr(), narrow_cast<int>(addr.get_sockaddr_len()),
                               nullptr, 0, nullptr, &read_overlapped_);

    if (status == TRUE || !check_status("Failed to connect")) {
      is_read_active_ = false;
      dec_refcnt();
    }
  }

  void close() {
    if (!is_write_waiting_ && is_connected_) {
      VLOG(fd) << get_native_fd() << " will close after ongoing write";
      auto lock = lock_.lock();
      if (!is_write_waiting_) {
        need_close_after_write_ = true;
        return;
      }
    }
    notify_iocp_close();
  }

  PollableFdInfo &get_poll_info() {
    return info_;
  }
  const PollableFdInfo &get_poll_info() const {
    return info_;
  }

  const NativeFd &get_native_fd() const {
    return info_.native_fd();
  }

  Result<size_t> write(Slice data) {
    // LOG(ERROR) << "Write: " << format::as_hex_dump<0>(data);
    output_writer_.append(data);
    return write_finish(data.size());
  }

  Result<size_t> writev(Span<IoSlice> slices) {
    size_t total_size = 0;
    for (auto io_slice : slices) {
      auto size = as_slice(io_slice).size();
      CHECK(size <= std::numeric_limits<size_t>::max() - total_size);
      total_size += size;
    }

    auto left_size = total_size;
    for (auto io_slice : slices) {
      auto slice = as_slice(io_slice);
      output_writer_.append(slice, left_size);
      left_size -= slice.size();
    }

    return write_finish(total_size);
  }

  Result<size_t> write_finish(size_t total_size) {
    if (is_write_waiting_) {
      auto lock = lock_.lock();
      is_write_waiting_ = false;
      lock.reset();
      notify_iocp_write();
    }
    return total_size;
  }

  Result<size_t> read(MutableSlice slice) {
    if (get_poll_info().get_flags_local().has_pending_error()) {
      TRY_STATUS(get_pending_error());
    }
    input_reader_.sync_with_writer();
    auto res = input_reader_.advance(td::min(slice.size(), input_reader_.size()), slice);
    if (res == 0) {
      get_poll_info().clear_flags(PollFlags::Read());
    } else {
      // LOG(ERROR) << "Read: " << format::as_hex_dump<0>(Slice(slice.substr(0, res)));
    }
    return res;
  }

  Status get_pending_error() {
    Status res;
    {
      auto lock = lock_.lock();
      if (!pending_errors_.empty()) {
        res = pending_errors_.pop();
      }
      if (res.is_ok()) {
        get_poll_info().clear_flags(PollFlags::Error());
      }
    }
    return res;
  }

 private:
  PollableFdInfo info_;
  Mutex lock_;

  std::atomic<int> refcnt_{1};
  bool close_flag_{false};
  bool need_close_after_write_{false};

  std::atomic<bool> is_connected_{false};
  bool is_read_active_{false};
  ChainBufferWriter input_writer_;
  ChainBufferReader input_reader_ = input_writer_.extract_reader();
  WSAOVERLAPPED read_overlapped_;
  VectorQueue<Status> pending_errors_;

  bool is_write_active_{false};
  std::atomic<bool> is_write_waiting_{false};
  ChainBufferWriter output_writer_;
  ChainBufferReader output_reader_ = output_writer_.extract_reader();
  WSAOVERLAPPED write_overlapped_;

  char close_overlapped_;

  bool check_status(Slice message) {
    auto last_error = WSAGetLastError();
    if (last_error == ERROR_IO_PENDING) {
      return true;
    }
    on_error(OS_SOCKET_ERROR(message));
    return false;
  }

  void loop_read() {
    CHECK(is_connected_);
    CHECK(!is_read_active_);
    if (close_flag_ || need_close_after_write_) {
      return;
    }
    std::memset(&read_overlapped_, 0, sizeof(read_overlapped_));
    auto dest = input_writer_.prepare_append();
    WSABUF buf;
    buf.len = narrow_cast<ULONG>(dest.size());
    buf.buf = dest.data();
    DWORD flags = 0;
    int status = WSARecv(get_native_fd().socket(), &buf, 1, nullptr, &flags, &read_overlapped_, nullptr);
    if (status == 0 || check_status("Failed to read from connection")) {
      inc_refcnt();
      is_read_active_ = true;
    }
  }

  void loop_write() {
    CHECK(is_connected_);
    CHECK(!is_write_active_);

    output_reader_.sync_with_writer();
    auto to_write = output_reader_.prepare_read();
    if (to_write.empty()) {
      auto lock = lock_.lock();
      output_reader_.sync_with_writer();
      to_write = output_reader_.prepare_read();
      if (to_write.empty()) {
        is_write_waiting_ = true;
        if (need_close_after_write_) {
          notify_iocp_close();
        }
        return;
      }
    }
    if (to_write.empty()) {
      return;
    }
    std::memset(&write_overlapped_, 0, sizeof(write_overlapped_));
    constexpr size_t BUF_SIZE = 20;
    WSABUF buf[BUF_SIZE];
    auto it = output_reader_.clone();
    size_t buf_i;
    for (buf_i = 0; buf_i < BUF_SIZE; buf_i++) {
      auto src = it.prepare_read();
      if (src.empty()) {
        break;
      }
      buf[buf_i].len = narrow_cast<ULONG>(src.size());
      buf[buf_i].buf = const_cast<CHAR *>(src.data());
      it.confirm_read(src.size());
    }
    int status =
        WSASend(get_native_fd().socket(), buf, narrow_cast<DWORD>(buf_i), nullptr, 0, &write_overlapped_, nullptr);
    if (status == 0 || check_status("Failed to write to connection")) {
      inc_refcnt();
      is_write_active_ = true;
    }
  }

  void on_iocp(Result<size_t> r_size, WSAOVERLAPPED *overlapped) final {
    // called from other thread
    if (dec_refcnt() || close_flag_) {
      VLOG(fd) << "Ignore IOCP (socket is closing)";
      return;
    }
    if (r_size.is_error()) {
      return on_error(get_socket_pending_error(get_native_fd(), overlapped, r_size.move_as_error()));
    }

    if (!is_connected_ && overlapped == &read_overlapped_) {
      return on_connected();
    }

    auto size = r_size.move_as_ok();
    if (overlapped == &write_overlapped_) {
      return on_write(size);
    }
    if (overlapped == nullptr) {
      CHECK(size == 0);
      return on_write(size);
    }

    if (overlapped == &read_overlapped_) {
      return on_read(size);
    }
    if (overlapped == reinterpret_cast<WSAOVERLAPPED *>(&close_overlapped_)) {
      return on_close();
    }
    LOG(ERROR) << this << ' ' << overlapped << ' ' << &read_overlapped_ << ' ' << &write_overlapped_ << ' '
               << reinterpret_cast<WSAOVERLAPPED *>(&close_overlapped_) << ' ' << size;
    LOG(FATAL) << get_native_fd() << ' ' << info_.get_flags_local() << ' ' << refcnt_.load() << ' ' << close_flag_
               << ' ' << need_close_after_write_ << ' ' << is_connected_ << ' ' << is_read_active_ << ' '
               << is_write_active_ << ' ' << is_write_waiting_.load() << ' ' << input_reader_.size() << ' '
               << output_reader_.size();
  }

  void on_error(Status status) {
    VLOG(fd) << get_native_fd() << " on error " << status;
    {
      auto lock = lock_.lock();
      pending_errors_.push(std::move(status));
    }
    get_poll_info().add_flags_from_poll(PollFlags::Error());
  }

  void on_connected() {
    VLOG(fd) << get_native_fd() << " on connected";
    CHECK(!is_connected_);
    CHECK(is_read_active_);
    is_connected_ = true;
    is_read_active_ = false;
    loop_read();
    loop_write();
  }

  void on_read(size_t size) {
    VLOG(fd) << get_native_fd() << " on read " << size;
    CHECK(is_read_active_);
    is_read_active_ = false;
    if (size == 0) {
      get_poll_info().add_flags_from_poll(PollFlags::Close());
      return;
    }
    input_writer_.confirm_append(size);
    get_poll_info().add_flags_from_poll(PollFlags::Read());
    loop_read();
  }

  void on_write(size_t size) {
    VLOG(fd) << get_native_fd() << " on write " << size;
    if (size == 0) {
      if (is_write_active_) {
        return;
      }
      is_write_active_ = true;
    }
    CHECK(is_write_active_);
    is_write_active_ = false;
    output_reader_.advance(size);
    loop_write();
  }

  void on_close() {
    VLOG(fd) << get_native_fd() << " on close";
    close_flag_ = true;
    info_.set_native_fd({});
  }
  bool dec_refcnt() {
    VLOG(fd) << get_native_fd() << " dec_refcnt from " << refcnt_;
    if (--refcnt_ == 0) {
      delete this;
      return true;
    }
    return false;
  }
  void inc_refcnt() {
    CHECK(refcnt_ != 0);
    refcnt_++;
    VLOG(fd) << get_native_fd() << " inc_refcnt to " << refcnt_;
  }

  void notify_iocp_write() {
    inc_refcnt();
    Iocp::get()->post(0, this, nullptr);
  }
  void notify_iocp_close() {
    Iocp::get()->post(0, this, reinterpret_cast<WSAOVERLAPPED *>(&close_overlapped_));
  }
  void notify_iocp_connected() {
    inc_refcnt();
    Iocp::get()->post(0, this, &read_overlapped_);
  }
};

void SocketFdImplDeleter::operator()(SocketFdImpl *impl) {
  impl->close();
}

class InitWSA {
 public:
  InitWSA() {
    /* Use the MAKEWORD(lowbyte, highbyte) macro declared in Windef.h */
    WORD wVersionRequested = MAKEWORD(2, 2);
    WSADATA wsaData;
    if (WSAStartup(wVersionRequested, &wsaData) != 0) {
      auto error = OS_SOCKET_ERROR("Failed to init WSA");
      LOG(FATAL) << error;
    }
  }
};

static InitWSA init_wsa;

#else
class SocketFdImpl {
 public:
  PollableFdInfo info_;
  explicit SocketFdImpl(NativeFd fd) : info_(std::move(fd)) {
  }
  PollableFdInfo &get_poll_info() {
    return info_;
  }
  const PollableFdInfo &get_poll_info() const {
    return info_;
  }

  const NativeFd &get_native_fd() const {
    return info_.native_fd();
  }

  Result<size_t> writev(Span<IoSlice> slices) {
    int native_fd = get_native_fd().socket();
    TRY_RESULT(slices_size, narrow_cast_safe<int>(slices.size()));
    auto write_res = detail::skip_eintr([&] {
    // sendmsg can erroneously return 2^32 - 1 on Android 5.1 and Android 6.0, so it must not be used there
#if defined(MSG_NOSIGNAL) && !TD_ANDROID
      msghdr msg;
      std::memset(&msg, 0, sizeof(msg));
      msg.msg_iov = const_cast<iovec *>(slices.begin());
      msg.msg_iovlen = slices_size;
      return sendmsg(native_fd, &msg, MSG_NOSIGNAL);
#else
      return ::writev(native_fd, slices.begin(), slices_size);
#endif
    });
    if (write_res >= 0) {
      auto result = narrow_cast<size_t>(write_res);
      auto left = result;
      for (const auto &slice : slices) {
        if (left <= slice.iov_len) {
          return result;
        }
        left -= slice.iov_len;
      }
      LOG(FATAL) << "Receive " << write_res << " as writev response, but tried to write only " << result - left
                 << " bytes";
    }
    return write_finish();
  }

  Result<size_t> write(Slice slice) {
    int native_fd = get_native_fd().socket();
    auto write_res = detail::skip_eintr([&] {
      return
#ifdef MSG_NOSIGNAL
          send(native_fd, slice.begin(), slice.size(), MSG_NOSIGNAL);
#else
          ::write(native_fd, slice.begin(), slice.size());
#endif
    });
    if (write_res >= 0) {
      auto result = narrow_cast<size_t>(write_res);
      LOG_CHECK(result <= slice.size()) << "Receive " << write_res << " as write response, but tried to write only "
                                        << slice.size() << " bytes";
      return result;
    }
    return write_finish();
  }

  Result<size_t> write_finish() {
    auto write_errno = errno;
    if (write_errno == EAGAIN
#if EAGAIN != EWOULDBLOCK
        || write_errno == EWOULDBLOCK
#endif
    ) {
      get_poll_info().clear_flags(PollFlags::Write());
      return 0;
    }

    auto error = Status::PosixError(write_errno, PSLICE() << "Write to " << get_native_fd() << " has failed");
    switch (write_errno) {
      case EBADF:
      case ENXIO:
      case EFAULT:
      case EINVAL:
        LOG(FATAL) << error;
        UNREACHABLE();
      default:
        LOG(WARNING) << error;
      // fallthrough
      case ECONNRESET:
      case EDQUOT:
      case EFBIG:
      case EIO:
      case ENETDOWN:
      case ENETUNREACH:
      case ENOSPC:
      case EPIPE:
        get_poll_info().clear_flags(PollFlags::Write());
        get_poll_info().add_flags(PollFlags::Close());
        return std::move(error);
    }
  }
  Result<size_t> read(MutableSlice slice) {
    if (get_poll_info().get_flags_local().has_pending_error()) {
      TRY_STATUS(get_pending_error());
    }
    int native_fd = get_native_fd().socket();
    CHECK(!slice.empty());
    auto read_res = detail::skip_eintr([&] { return ::read(native_fd, slice.begin(), slice.size()); });
    auto read_errno = errno;
    if (read_res >= 0) {
      if (read_res == 0) {
        errno = 0;
        get_poll_info().clear_flags(PollFlags::Read());
        get_poll_info().add_flags(PollFlags::Close());
      }
      auto result = narrow_cast<size_t>(read_res);
      CHECK(result <= slice.size());
      return result;
    }
    if (read_errno == EAGAIN
#if EAGAIN != EWOULDBLOCK
        || read_errno == EWOULDBLOCK
#endif
    ) {
      get_poll_info().clear_flags(PollFlags::Read());
      return 0;
    }
    auto error = Status::PosixError(read_errno, PSLICE() << "Read from " << get_native_fd() << " has failed");
    switch (read_errno) {
      case EISDIR:
      case EBADF:
      case ENXIO:
      case EINVAL:
        LOG(FATAL) << error;
        UNREACHABLE();
      case EFAULT:  // happens on various Android 13 phones manufactured by BBK Electronics
      default:
        LOG(WARNING) << error;
      // fallthrough
      case ENOTCONN:
      case EIO:
      case ENOBUFS:
      case ENOMEM:
      case ECONNRESET:
      case ETIMEDOUT:
        get_poll_info().clear_flags(PollFlags::Read());
        get_poll_info().add_flags(PollFlags::Close());
        return std::move(error);
    }
  }
  Status get_pending_error() {
    if (!get_poll_info().get_flags_local().has_pending_error()) {
      return Status::OK();
    }
    TRY_STATUS(detail::get_socket_pending_error(get_native_fd()));
    get_poll_info().clear_flags(PollFlags::Error());
    return Status::OK();
  }
};

void SocketFdImplDeleter::operator()(SocketFdImpl *impl) {
  delete impl;
}

#endif

#if TD_PORT_POSIX
Status get_socket_pending_error(const NativeFd &fd) {
  int error = 0;
  socklen_t errlen = sizeof(error);
  if (getsockopt(fd.socket(), SOL_SOCKET, SO_ERROR, static_cast<void *>(&error), &errlen) == 0) {
    if (error == 0) {
      return Status::OK();
    }
    return Status::PosixError(error, PSLICE() << "Error on " << fd);
  }
  auto status = OS_SOCKET_ERROR(PSLICE() << "Can't load error on socket " << fd);
  LOG(INFO) << "Can't load pending socket error: " << status;
  return status;
}
#elif TD_PORT_WINDOWS
Status get_socket_pending_error(const NativeFd &fd, WSAOVERLAPPED *overlapped, Status iocp_error) {
  // We need to call WSAGetOverlappedResult() just so WSAGetLastError() will return the correct error. See
  // https://stackoverflow.com/questions/28925003/calling-wsagetlasterror-from-an-iocp-thread-return-incorrect-result
  DWORD num_bytes = 0;
  DWORD flags = 0;
  BOOL success = WSAGetOverlappedResult(fd.socket(), overlapped, &num_bytes, false, &flags);
  if (success) {
    LOG(ERROR) << "WSAGetOverlappedResult succeeded after " << iocp_error;
    return iocp_error;
  }
  return OS_SOCKET_ERROR(PSLICE() << "Error on " << fd);
}
#endif

Status init_socket_options(NativeFd &native_fd) {
  TRY_STATUS(native_fd.set_is_blocking_unsafe(false));

  auto sock = native_fd.socket();
#if TD_PORT_POSIX
  int flags = 1;
#elif TD_PORT_WINDOWS
  BOOL flags = TRUE;
#endif
  setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, reinterpret_cast<const char *>(&flags), sizeof(flags));
  setsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, reinterpret_cast<const char *>(&flags), sizeof(flags));
  setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, reinterpret_cast<const char *>(&flags), sizeof(flags));
#if TD_PORT_POSIX
#ifndef MSG_NOSIGNAL  // Darwin

#ifdef SO_NOSIGPIPE
  setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, reinterpret_cast<const char *>(&flags), sizeof(flags));
#else
#warning "Failed to suppress SIGPIPE signals. Use signal(SIGPIPE, SIG_IGN) to suppress them."
#endif

#endif
#endif
  // TODO: SO_REUSEADDR, SO_KEEPALIVE, TCP_NODELAY, SO_SNDBUF, SO_RCVBUF, TCP_QUICKACK, SO_LINGER

  return Status::OK();
}

}  // namespace detail

SocketFd::SocketFd() = default;
SocketFd::SocketFd(SocketFd &&) noexcept = default;
SocketFd &SocketFd::operator=(SocketFd &&) noexcept = default;
SocketFd::~SocketFd() = default;

SocketFd::SocketFd(unique_ptr<detail::SocketFdImpl> impl) : impl_(impl.release()) {
}

Result<SocketFd> SocketFd::from_native_fd(NativeFd fd) {
  TRY_STATUS(detail::init_socket_options(fd));
  return SocketFd(make_unique<detail::SocketFdImpl>(std::move(fd)));
}

Result<SocketFd> SocketFd::open(const IPAddress &address) {
#if TD_DARWIN_WATCH_OS
  return SocketFd{};
#endif

  NativeFd native_fd{socket(address.get_address_family(), SOCK_STREAM, IPPROTO_TCP)};
  if (!native_fd) {
    return OS_SOCKET_ERROR("Failed to create a socket");
  }
#if TD_PORT_POSIX
  // Avoid the use of low-numbered file descriptors, which can be used directly by some other functions
  constexpr int MINIMUM_FILE_DESCRIPTOR = 3;
  while (native_fd.socket() < MINIMUM_FILE_DESCRIPTOR) {
    native_fd.close();
    LOG(ERROR) << "Receive " << native_fd << " as a file descriptor";
    int dummy_fd = detail::skip_eintr([&] { return ::open("/dev/null", O_RDONLY, 0); });
    if (dummy_fd < 0) {
      return OS_ERROR("Can't open /dev/null");
    }
    native_fd = NativeFd{socket(address.get_address_family(), SOCK_STREAM, IPPROTO_TCP)};
    if (!native_fd) {
      return OS_SOCKET_ERROR("Failed to create a socket");
    }
  }
#endif
  TRY_STATUS(detail::init_socket_options(native_fd));

#if TD_PORT_POSIX
  int e_connect =
      connect(native_fd.socket(), address.get_sockaddr(), narrow_cast<socklen_t>(address.get_sockaddr_len()));
  if (e_connect == -1) {
    auto connect_errno = errno;
    if (connect_errno != EINPROGRESS) {
      return Status::PosixError(connect_errno, PSLICE() << "Failed to connect to " << address);
    }
  }
  return SocketFd(make_unique<detail::SocketFdImpl>(std::move(native_fd)));
#elif TD_PORT_WINDOWS
  auto bind_addr = address.get_any_addr();
  auto e_bind = bind(native_fd.socket(), bind_addr.get_sockaddr(), narrow_cast<int>(bind_addr.get_sockaddr_len()));
  if (e_bind != 0) {
    return OS_SOCKET_ERROR("Failed to bind a socket");
  }
  return SocketFd(make_unique<detail::SocketFdImpl>(std::move(native_fd), address));
#endif
}

void SocketFd::close() {
  impl_.reset();
}

bool SocketFd::empty() const {
  return !impl_;
}

PollableFdInfo &SocketFd::get_poll_info() {
  CHECK(!empty());
  return impl_->get_poll_info();
}
const PollableFdInfo &SocketFd::get_poll_info() const {
  CHECK(!empty());
  return impl_->get_poll_info();
}

const NativeFd &SocketFd::get_native_fd() const {
  CHECK(!empty());
  return impl_->get_native_fd();
}

Status SocketFd::get_pending_error() {
  CHECK(!empty());
  return impl_->get_pending_error();
}

Result<size_t> SocketFd::write(Slice slice) {
  CHECK(!empty());
  return impl_->write(slice);
}

Result<size_t> SocketFd::writev(Span<IoSlice> slices) {
  CHECK(!empty());
  return impl_->writev(slices);
}

Result<size_t> SocketFd::read(MutableSlice slice) {
  CHECK(!empty());
  return impl_->read(slice);
}

Result<uint32> SocketFd::maximize_snd_buffer(uint32 max_size) {
  return get_native_fd().maximize_snd_buffer(max_size);
}

Result<uint32> SocketFd::maximize_rcv_buffer(uint32 max_size) {
  return get_native_fd().maximize_rcv_buffer(max_size);
}

}  // namespace td
