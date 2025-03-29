//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/port/UdpSocketFd.h"

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/detail/skip_eintr.h"
#include "td/utils/port/PollFlags.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/VectorQueue.h"

#if TD_PORT_WINDOWS
#include "td/utils/port/detail/Iocp.h"
#include "td/utils/port/Mutex.h"
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

#if TD_LINUX
#include <linux/errqueue.h>
#endif
#endif

#include <array>
#include <atomic>
#include <cstring>

namespace td {
namespace detail {
#if TD_PORT_WINDOWS
class UdpSocketReceiveHelper {
 public:
  void to_native(const UdpMessage &message, WSAMSG &message_header) {
    socklen_t addr_len{narrow_cast<socklen_t>(sizeof(addr_))};
    message_header.name = reinterpret_cast<sockaddr *>(&addr_);
    message_header.namelen = addr_len;
    buf_.buf = const_cast<char *>(message.data.as_slice().begin());
    buf_.len = narrow_cast<DWORD>(message.data.size());
    message_header.lpBuffers = &buf_;
    message_header.dwBufferCount = 1;
    message_header.Control.buf = nullptr;  // control_buf_.data();
    message_header.Control.len = 0;        // narrow_cast<decltype(message_header.Control.len)>(control_buf_.size());
    message_header.dwFlags = 0;
  }

  static void from_native(WSAMSG &message_header, size_t message_size, UdpMessage &message) {
    message.address.init_sockaddr(reinterpret_cast<sockaddr *>(message_header.name), message_header.namelen).ignore();
    message.error = Status::OK();

    if ((message_header.dwFlags & (MSG_TRUNC | MSG_CTRUNC)) != 0) {
      message.error = Status::Error(501, "Message too long");
      message.data = BufferSlice();
      return;
    }

    CHECK(message_size <= message.data.size());
    message.data.truncate(message_size);
    CHECK(message_size == message.data.size());
  }

 private:
  std::array<char, 1024> control_buf_;
  sockaddr_storage addr_;
  WSABUF buf_;
};

class UdpSocketSendHelper {
 public:
  void to_native(const UdpMessage &message, WSAMSG &message_header) {
    message_header.name = const_cast<sockaddr *>(message.address.get_sockaddr());
    message_header.namelen = narrow_cast<socklen_t>(message.address.get_sockaddr_len());
    buf_.buf = const_cast<char *>(message.data.as_slice().begin());
    buf_.len = narrow_cast<DWORD>(message.data.size());
    message_header.lpBuffers = &buf_;
    message_header.dwBufferCount = 1;

    message_header.Control.buf = nullptr;
    message_header.Control.len = 0;
    message_header.dwFlags = 0;
  }

 private:
  WSABUF buf_;
};

class UdpSocketFdImpl final : private Iocp::Callback {
 public:
  explicit UdpSocketFdImpl(NativeFd fd) : info_(std::move(fd)) {
    get_poll_info().add_flags(PollFlags::Write());
    Iocp::get()->subscribe(get_native_fd(), this);
    is_receive_active_ = true;
    notify_iocp_connected();
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

  void close() {
    notify_iocp_close();
  }

  Result<optional<UdpMessage>> receive() {
    auto lock = lock_.lock();
    if (!pending_errors_.empty()) {
      auto status = pending_errors_.pop();
      if (!UdpSocketFd::is_critical_read_error(status)) {
        return UdpMessage{{}, {}, std::move(status)};
      }
      return std::move(status);
    }
    if (!receive_queue_.empty()) {
      return receive_queue_.pop();
    }

    return optional<UdpMessage>{};
  }

  void send(UdpMessage message) {
    auto lock = lock_.lock();
    send_queue_.push(std::move(message));
  }

  Status flush_send() {
    if (is_send_waiting_) {
      auto lock = lock_.lock();
      is_send_waiting_ = false;
      notify_iocp_send();
    }
    return Status::OK();
  }

 private:
  PollableFdInfo info_;
  Mutex lock_;

  std::atomic<int> refcnt_{1};
  bool is_connected_{false};
  bool close_flag_{false};

  bool is_send_active_{false};
  bool is_send_waiting_{false};
  VectorQueue<UdpMessage> send_queue_;
  WSAOVERLAPPED send_overlapped_;

  bool is_receive_active_{false};
  VectorQueue<UdpMessage> receive_queue_;
  VectorQueue<Status> pending_errors_;
  UdpMessage to_receive_;
  WSAMSG receive_message_;
  UdpSocketReceiveHelper receive_helper_;
  static constexpr size_t MAX_PACKET_SIZE = 2048;
  static constexpr size_t RESERVED_SIZE = MAX_PACKET_SIZE * 8;
  BufferSlice receive_buffer_;

  UdpMessage to_send_;
  WSAOVERLAPPED receive_overlapped_;

  char close_overlapped_;

  bool check_status(Slice message) {
    auto last_error = WSAGetLastError();
    if (last_error == ERROR_IO_PENDING) {
      return true;
    }
    on_error(OS_SOCKET_ERROR(message));
    return false;
  }

  void loop_receive() {
    CHECK(!is_receive_active_);
    if (close_flag_) {
      return;
    }
    std::memset(&receive_overlapped_, 0, sizeof(receive_overlapped_));
    if (receive_buffer_.size() < MAX_PACKET_SIZE) {
      receive_buffer_ = BufferSlice(RESERVED_SIZE);
    }
    to_receive_.data = receive_buffer_.clone();
    receive_helper_.to_native(to_receive_, receive_message_);

    LPFN_WSARECVMSG WSARecvMsgPtr = nullptr;
    GUID guid = WSAID_WSARECVMSG;
    DWORD numBytes;
    auto error = ::WSAIoctl(get_native_fd().socket(), SIO_GET_EXTENSION_FUNCTION_POINTER, static_cast<void *>(&guid),
                            sizeof(guid), static_cast<void *>(&WSARecvMsgPtr), sizeof(WSARecvMsgPtr), &numBytes,
                            nullptr, nullptr);
    if (error) {
      on_error(OS_SOCKET_ERROR("WSAIoctl failed"));
      return;
    }

    auto status = WSARecvMsgPtr(get_native_fd().socket(), &receive_message_, nullptr, &receive_overlapped_, nullptr);
    if (status == 0 || check_status("WSARecvMsg failed")) {
      inc_refcnt();
      is_receive_active_ = true;
    }
  }

  void loop_send() {
    CHECK(!is_send_active_);

    {
      auto lock = lock_.lock();
      if (send_queue_.empty()) {
        is_send_waiting_ = true;
        return;
      }
      to_send_ = send_queue_.pop();
    }
    std::memset(&send_overlapped_, 0, sizeof(send_overlapped_));
    WSAMSG message;
    UdpSocketSendHelper send_helper;
    send_helper.to_native(to_send_, message);
    auto status = WSASendMsg(get_native_fd().socket(), &message, 0, nullptr, &send_overlapped_, nullptr);
    if (status == 0 || check_status("WSASendMsg failed")) {
      inc_refcnt();
      is_send_active_ = true;
    }
  }

  void on_iocp(Result<size_t> r_size, WSAOVERLAPPED *overlapped) final {
    // called from other thread
    if (dec_refcnt() || close_flag_) {
      VLOG(fd) << "Ignore IOCP (UDP socket is closing)";
      return;
    }
    if (r_size.is_error()) {
      return on_error(get_socket_pending_error(get_native_fd(), overlapped, r_size.move_as_error()));
    }

    if (!is_connected_ && overlapped == &receive_overlapped_) {
      return on_connected();
    }

    auto size = r_size.move_as_ok();
    if (overlapped == &send_overlapped_) {
      return on_send(size);
    }
    if (overlapped == nullptr) {
      CHECK(size == 0);
      return on_send(size);
    }

    if (overlapped == &receive_overlapped_) {
      return on_receive(size);
    }
    if (overlapped == reinterpret_cast<WSAOVERLAPPED *>(&close_overlapped_)) {
      return on_close();
    }
    UNREACHABLE();
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
    CHECK(is_receive_active_);
    is_connected_ = true;
    is_receive_active_ = false;
    loop_receive();
    loop_send();
  }

  void on_receive(size_t size) {
    VLOG(fd) << get_native_fd() << " on receive " << size;
    CHECK(is_receive_active_);
    is_receive_active_ = false;
    UdpSocketReceiveHelper::from_native(receive_message_, size, to_receive_);
    receive_buffer_.confirm_read((to_receive_.data.size() + 7) & ~7);
    {
      auto lock = lock_.lock();
      // LOG(ERROR) << format::escaped(to_receive_.data.as_slice());
      receive_queue_.push(std::move(to_receive_));
    }
    get_poll_info().add_flags_from_poll(PollFlags::Read());
    loop_receive();
  }

  void on_send(size_t size) {
    VLOG(fd) << get_native_fd() << " on send " << size;
    if (size == 0) {
      if (is_send_active_) {
        return;
      }
      is_send_active_ = true;
    }
    CHECK(is_send_active_);
    is_send_active_ = false;
    loop_send();
  }

  void on_close() {
    VLOG(fd) << get_native_fd() << " on close";
    close_flag_ = true;
    info_.set_native_fd({});
  }

  bool dec_refcnt() {
    if (--refcnt_ == 0) {
      delete this;
      return true;
    }
    return false;
  }

  void inc_refcnt() {
    CHECK(refcnt_ != 0);
    refcnt_++;
  }

  void notify_iocp_send() {
    inc_refcnt();
    Iocp::get()->post(0, this, nullptr);
  }
  void notify_iocp_close() {
    Iocp::get()->post(0, this, reinterpret_cast<WSAOVERLAPPED *>(&close_overlapped_));
  }
  void notify_iocp_connected() {
    inc_refcnt();
    Iocp::get()->post(0, this, reinterpret_cast<WSAOVERLAPPED *>(&receive_overlapped_));
  }
};

void UdpSocketFdImplDeleter::operator()(UdpSocketFdImpl *impl) {
  impl->close();
}

#elif TD_PORT_POSIX
//struct iovec {                  [> Scatter/gather array items <]
//  void  *iov_base;              [> Starting address <]
//  size_t iov_len;               [> Number of bytes to transfer <]
//};

//struct msghdr {
//  void         *msg_name;       [> optional address <]
//  socklen_t     msg_namelen;    [> size of address <]
//  struct iovec *msg_iov;        [> scatter/gather array <]
//  size_t        msg_iovlen;     [> # elements in msg_iov <]
//  void         *msg_control;    [> ancillary data, see below <]
//  size_t        msg_controllen; [> ancillary data buffer len <]
//  int           msg_flags;      [> flags on received message <]
//};

class UdpSocketReceiveHelper {
 public:
  void to_native(const UdpSocketFd::InboundMessage &message, msghdr &message_header) {
    socklen_t addr_len{narrow_cast<socklen_t>(sizeof(addr_))};

    message_header.msg_name = &addr_;
    message_header.msg_namelen = addr_len;
    io_vec_.iov_base = message.data.begin();
    io_vec_.iov_len = message.data.size();
    message_header.msg_iov = &io_vec_;
    message_header.msg_iovlen = 1;
    message_header.msg_control = control_buf_.data();
    message_header.msg_controllen = narrow_cast<decltype(message_header.msg_controllen)>(control_buf_.size());
    message_header.msg_flags = 0;
  }

  static void from_native(msghdr &message_header, size_t message_size, UdpSocketFd::InboundMessage &message) {
#if TD_LINUX
    cmsghdr *cmsg;
    sock_extended_err *ee = nullptr;
    for (cmsg = CMSG_FIRSTHDR(&message_header); cmsg != nullptr; cmsg = CMSG_NXTHDR(&message_header, cmsg)) {
      if (cmsg->cmsg_type == IP_PKTINFO && cmsg->cmsg_level == IPPROTO_IP) {
        //auto *pi = reinterpret_cast<in_pktinfo *>(CMSG_DATA(cmsg));
      } else if (cmsg->cmsg_type == IPV6_PKTINFO && cmsg->cmsg_level == IPPROTO_IPV6) {
        //auto *pi = reinterpret_cast<in6_pktinfo *>(CMSG_DATA(cmsg));
      } else if ((cmsg->cmsg_type == IP_RECVERR && cmsg->cmsg_level == IPPROTO_IP) ||
                 (cmsg->cmsg_type == IPV6_RECVERR && cmsg->cmsg_level == IPPROTO_IPV6)) {
        ee = reinterpret_cast<sock_extended_err *>(CMSG_DATA(cmsg));
      }
    }
    if (ee != nullptr) {
      auto *addr = reinterpret_cast<sockaddr *>(SO_EE_OFFENDER(ee));
      IPAddress address;
      address.init_sockaddr(addr).ignore();
      if (message.from != nullptr) {
        *message.from = address;
      }
      if (message.error) {
        *message.error = Status::PosixError(ee->ee_errno, "");
      }
      //message.data = MutableSlice();
      message.data.truncate(0);
      return;
    }
#endif
    if (message.from != nullptr) {
      message.from->init_sockaddr(reinterpret_cast<sockaddr *>(message_header.msg_name), message_header.msg_namelen)
          .ignore();
    }
    if (message.error) {
      *message.error = Status::OK();
    }
    if (message_header.msg_flags & MSG_TRUNC) {
      if (message.error) {
        *message.error = Status::Error(501, "Message too long");
      }
      message.data.truncate(0);
      return;
    }
    CHECK(message_size <= message.data.size());
    message.data.truncate(message_size);
    CHECK(message_size == message.data.size());
  }

 private:
  std::array<char, 1024> control_buf_;
  sockaddr_storage addr_;
  iovec io_vec_;
};

class UdpSocketSendHelper {
 public:
  void to_native(const UdpSocketFd::OutboundMessage &message, msghdr &message_header) {
    CHECK(message.to != nullptr && message.to->is_valid());
    message_header.msg_name = const_cast<sockaddr *>(message.to->get_sockaddr());
    message_header.msg_namelen = narrow_cast<socklen_t>(message.to->get_sockaddr_len());
    io_vec_.iov_base = const_cast<char *>(message.data.begin());
    io_vec_.iov_len = message.data.size();
    message_header.msg_iov = &io_vec_;
    message_header.msg_iovlen = 1;
    //TODO
    message_header.msg_control = nullptr;
    message_header.msg_controllen = 0;
    message_header.msg_flags = 0;
  }

 private:
  iovec io_vec_;
};

class UdpSocketFdImpl {
 public:
  explicit UdpSocketFdImpl(NativeFd fd) : info_(std::move(fd)) {
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
  Status get_pending_error() {
    if (!get_poll_info().get_flags_local().has_pending_error()) {
      return Status::OK();
    }
    TRY_STATUS(detail::get_socket_pending_error(get_native_fd()));
    get_poll_info().clear_flags(PollFlags::Error());
    return Status::OK();
  }
  Status receive_message(UdpSocketFd::InboundMessage &message, bool &is_received) {
    is_received = false;
    int flags = 0;
    if (get_poll_info().get_flags_local().has_pending_error()) {
#ifdef MSG_ERRQUEUE
      flags = MSG_ERRQUEUE;
#else
      return get_pending_error();
#endif
    }

    msghdr message_header;
    detail::UdpSocketReceiveHelper helper;
    helper.to_native(message, message_header);

    auto native_fd = get_native_fd().socket();
    auto recvmsg_res = detail::skip_eintr([&] { return recvmsg(native_fd, &message_header, flags); });
    auto recvmsg_errno = errno;
    if (recvmsg_res >= 0) {
      UdpSocketReceiveHelper::from_native(message_header, recvmsg_res, message);
      is_received = true;
      return Status::OK();
    }
    return process_recvmsg_error(recvmsg_errno, is_received);
  }

  Status process_recvmsg_error(int recvmsg_errno, bool &is_received) {
    is_received = false;
    if (recvmsg_errno == EAGAIN
#if EAGAIN != EWOULDBLOCK
        || recvmsg_errno == EWOULDBLOCK
#endif
    ) {
      if (get_poll_info().get_flags_local().has_pending_error()) {
        get_poll_info().clear_flags(PollFlags::Error());
      } else {
        get_poll_info().clear_flags(PollFlags::Read());
      }
      return Status::OK();
    }

    auto error = Status::PosixError(recvmsg_errno, PSLICE() << "Receive from " << get_native_fd() << " has failed");
    switch (recvmsg_errno) {
      case EBADF:
      case EFAULT:
      case EINVAL:
      case ENOTCONN:
      case ECONNRESET:
      case ETIMEDOUT:
        LOG(FATAL) << error;
        UNREACHABLE();
      default:
        LOG(WARNING) << "Unknown error: " << error;
      // fallthrough
      case ENOBUFS:
      case ENOMEM:
#ifdef MSG_ERRQUEUE
        get_poll_info().add_flags(PollFlags::Error());
#endif
        return error;
    }
  }

  Status send_message(const UdpSocketFd::OutboundMessage &message, bool &is_sent) {
    is_sent = false;
    msghdr message_header;
    detail::UdpSocketSendHelper helper;
    helper.to_native(message, message_header);

    auto native_fd = get_native_fd().socket();
    auto sendmsg_res = detail::skip_eintr([&] { return sendmsg(native_fd, &message_header, 0); });
    auto sendmsg_errno = errno;
    if (sendmsg_res >= 0) {
      is_sent = true;
      return Status::OK();
    }
    return process_sendmsg_error(sendmsg_errno, is_sent);
  }
  Status process_sendmsg_error(int sendmsg_errno, bool &is_sent) {
    if (sendmsg_errno == EAGAIN
#if EAGAIN != EWOULDBLOCK
        || sendmsg_errno == EWOULDBLOCK
#endif
    ) {
      get_poll_info().clear_flags(PollFlags::Write());
      return Status::OK();
    }

    auto error = Status::PosixError(sendmsg_errno, PSLICE() << "Send from " << get_native_fd() << " has failed");
    switch (sendmsg_errno) {
      // We still may send some other packets, but there is no point to resend this particular message
      case EACCES:
      case EMSGSIZE:
      case EPERM:
        LOG(WARNING) << "Silently drop packet :( " << error;
        //TODO: get errors from MSG_ERRQUEUE is possible
        is_sent = true;
        return error;

      // Some general issues, which may be fixed in the future
      case ENOMEM:
      case EDQUOT:
      case EFBIG:
      case ENETDOWN:
      case ENETUNREACH:
      case ENOSPC:
      case EHOSTUNREACH:
      case ENOBUFS:
      default:
#ifdef MSG_ERRQUEUE
        get_poll_info().add_flags(PollFlags::Error());
#endif
        return error;

      case EBADF:         // impossible
      case ENOTSOCK:      // impossible
      case EPIPE:         // impossible for UDP
      case ECONNRESET:    // impossible for UDP
      case EDESTADDRREQ:  // we checked that address is valid
      case ENOTCONN:      // we checked that address is valid
      case EINTR:         // we already skipped all EINTR
      case EISCONN:       // impossible for UDP socket
      case EOPNOTSUPP:
      case ENOTDIR:
      case EFAULT:
      case EINVAL:
      case EAFNOSUPPORT:
        LOG(FATAL) << error;
        UNREACHABLE();
        return error;
    }
  }

  Status send_messages(Span<UdpSocketFd::OutboundMessage> messages, size_t &cnt) {
#if TD_HAS_MMSG
    return send_messages_fast(messages, cnt);
#else
    return send_messages_slow(messages, cnt);
#endif
  }

  Status receive_messages(MutableSpan<UdpSocketFd::InboundMessage> messages, size_t &cnt) {
#if TD_HAS_MMSG
    return receive_messages_fast(messages, cnt);
#else
    return receive_messages_slow(messages, cnt);
#endif
  }

 private:
  PollableFdInfo info_;

  Status send_messages_slow(Span<UdpSocketFd::OutboundMessage> messages, size_t &cnt) {
    cnt = 0;
    for (auto &message : messages) {
      CHECK(!message.data.empty());
      bool is_sent;
      auto error = send_message(message, is_sent);
      cnt += is_sent;
      TRY_STATUS(std::move(error));
    }
    return Status::OK();
  }

#if TD_HAS_MMSG
  Status send_messages_fast(Span<UdpSocketFd::OutboundMessage> messages, size_t &cnt) {
    //struct mmsghdr {
    //  msghdr msg_hdr;        [> Message header <]
    //  unsigned int msg_len;  [> Number of bytes transmitted <]
    //};
    std::array<detail::UdpSocketSendHelper, 16> helpers;
    std::array<mmsghdr, 16> headers;
    size_t to_send = min(messages.size(), headers.size());
    for (size_t i = 0; i < to_send; i++) {
      helpers[i].to_native(messages[i], headers[i].msg_hdr);
      headers[i].msg_len = 0;
    }

    auto native_fd = get_native_fd().socket();
    auto sendmmsg_res =
        detail::skip_eintr([&] { return sendmmsg(native_fd, headers.data(), narrow_cast<unsigned int>(to_send), 0); });
    auto sendmmsg_errno = errno;
    if (sendmmsg_res >= 0) {
      cnt = sendmmsg_res;
      return Status::OK();
    }

    bool is_sent = false;
    auto status = process_sendmsg_error(sendmmsg_errno, is_sent);
    cnt = is_sent;
    return status;
  }
#endif
  Status receive_messages_slow(MutableSpan<UdpSocketFd::InboundMessage> messages, size_t &cnt) {
    cnt = 0;
    while (cnt < messages.size() && get_poll_info().get_flags_local().can_read()) {
      auto &message = messages[cnt];
      CHECK(!message.data.empty());
      bool is_received;
      auto error = receive_message(message, is_received);
      cnt += is_received;
      TRY_STATUS(std::move(error));
    }
    return Status::OK();
  }

#if TD_HAS_MMSG
  Status receive_messages_fast(MutableSpan<UdpSocketFd::InboundMessage> messages, size_t &cnt) {
    int flags = 0;
    cnt = 0;
    if (get_poll_info().get_flags_local().has_pending_error()) {
#ifdef MSG_ERRQUEUE
      flags = MSG_ERRQUEUE;
#else
      return get_pending_error();
#endif
    }
    //struct mmsghdr {
    //  msghdr msg_hdr;        [> Message header <]
    //  unsigned int msg_len;  [> Number of bytes transmitted <]
    //};
    std::array<detail::UdpSocketReceiveHelper, 16> helpers;
    std::array<mmsghdr, 16> headers;
    size_t to_receive = min(messages.size(), headers.size());
    for (size_t i = 0; i < to_receive; i++) {
      helpers[i].to_native(messages[i], headers[i].msg_hdr);
      headers[i].msg_len = 0;
    }

    auto native_fd = get_native_fd().socket();
    auto recvmmsg_res = detail::skip_eintr(
        [&] { return recvmmsg(native_fd, headers.data(), narrow_cast<unsigned int>(to_receive), flags, nullptr); });
    auto recvmmsg_errno = errno;
    if (recvmmsg_res >= 0) {
      cnt = narrow_cast<size_t>(recvmmsg_res);
      for (size_t i = 0; i < cnt; i++) {
        UdpSocketReceiveHelper::from_native(headers[i].msg_hdr, headers[i].msg_len, messages[i]);
      }
      return Status::OK();
    }

    bool is_received;
    auto status = process_recvmsg_error(recvmmsg_errno, is_received);
    cnt = is_received;
    return status;
  }
#endif
};
void UdpSocketFdImplDeleter::operator()(UdpSocketFdImpl *impl) {
  delete impl;
}
#endif
}  // namespace detail

UdpSocketFd::UdpSocketFd() = default;
UdpSocketFd::UdpSocketFd(UdpSocketFd &&) noexcept = default;
UdpSocketFd &UdpSocketFd::operator=(UdpSocketFd &&) noexcept = default;
UdpSocketFd::~UdpSocketFd() = default;
PollableFdInfo &UdpSocketFd::get_poll_info() {
  return impl_->get_poll_info();
}
const PollableFdInfo &UdpSocketFd::get_poll_info() const {
  return impl_->get_poll_info();
}

Result<UdpSocketFd> UdpSocketFd::open(const IPAddress &address) {
  NativeFd native_fd{socket(address.get_address_family(), SOCK_DGRAM, IPPROTO_UDP)};
  if (!native_fd) {
    return OS_SOCKET_ERROR("Failed to create a socket");
  }
  TRY_STATUS(native_fd.set_is_blocking_unsafe(false));

  auto sock = native_fd.socket();
#if TD_PORT_POSIX
  int flags = 1;
#elif TD_PORT_WINDOWS
  BOOL flags = TRUE;
#endif
  setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, reinterpret_cast<const char *>(&flags), sizeof(flags));
  // TODO: SO_REUSEADDR, SO_KEEPALIVE, TCP_NODELAY, SO_SNDBUF, SO_RCVBUF, TCP_QUICKACK, SO_LINGER

  auto bind_addr = address.get_any_addr();
  bind_addr.set_port(address.get_port());
  auto e_bind = bind(sock, bind_addr.get_sockaddr(), narrow_cast<int>(bind_addr.get_sockaddr_len()));
  if (e_bind != 0) {
    return OS_SOCKET_ERROR("Failed to bind a socket");
  }
  return UdpSocketFd(make_unique<detail::UdpSocketFdImpl>(std::move(native_fd)));
}

UdpSocketFd::UdpSocketFd(unique_ptr<detail::UdpSocketFdImpl> impl) : impl_(impl.release()) {
}

void UdpSocketFd::close() {
  impl_.reset();
}

bool UdpSocketFd::empty() const {
  return !impl_;
}

const NativeFd &UdpSocketFd::get_native_fd() const {
  return get_poll_info().native_fd();
}

#if TD_PORT_POSIX
Status UdpSocketFd::send_message(const OutboundMessage &message, bool &is_sent) {
  return impl_->send_message(message, is_sent);
}
Status UdpSocketFd::receive_message(InboundMessage &message, bool &is_received) {
  return impl_->receive_message(message, is_received);
}

Status UdpSocketFd::send_messages(Span<OutboundMessage> messages, size_t &count) {
  return impl_->send_messages(messages, count);
}
Status UdpSocketFd::receive_messages(MutableSpan<InboundMessage> messages, size_t &count) {
  return impl_->receive_messages(messages, count);
}
#endif
#if TD_PORT_WINDOWS
Result<optional<UdpMessage>> UdpSocketFd::receive() {
  return impl_->receive();
}

void UdpSocketFd::send(UdpMessage message) {
  return impl_->send(std::move(message));
}

Status UdpSocketFd::flush_send() {
  return impl_->flush_send();
}
#endif

bool UdpSocketFd::is_critical_read_error(const Status &status) {
  return status.code() == ENOMEM || status.code() == ENOBUFS;
}

Result<uint32> UdpSocketFd::maximize_snd_buffer(uint32 max_size) {
  return get_native_fd().maximize_snd_buffer(max_size);
}

Result<uint32> UdpSocketFd::maximize_rcv_buffer(uint32 max_size) {
  return get_native_fd().maximize_rcv_buffer(max_size);
}

}  // namespace td
