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

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/optional.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/port/UdpSocketFd.h"
#include "td/utils/Span.h"
#include "td/utils/Status.h"
#include "td/utils/VectorQueue.h"

#include <array>

namespace td {

#if TD_PORT_POSIX
namespace detail {
class UdpWriter {
 public:
  static Status write_once(UdpSocketFd &fd, VectorQueue<UdpMessage> &queue) TD_WARN_UNUSED_RESULT {
    std::array<UdpSocketFd::OutboundMessage, 16> messages;
    auto to_send = queue.as_span();
    size_t to_send_n = td::min(messages.size(), to_send.size());
    to_send.truncate(to_send_n);
    for (size_t i = 0; i < to_send_n; i++) {
      messages[i].to = &to_send[i].address;
      messages[i].data = to_send[i].data.as_slice();
    }

    size_t cnt;
    auto status = fd.send_messages(::td::Span<UdpSocketFd::OutboundMessage>(messages).truncate(to_send_n), cnt);
    queue.pop_n(cnt);
    return status;
  }
};

class UdpReaderHelper {
 public:
  void init_inbound_message(UdpSocketFd::InboundMessage &message) {
    message.from = &message_.address;
    message.error = &message_.error;
    if (buffer_.size() < MAX_PACKET_SIZE) {
      buffer_ = BufferSlice(RESERVED_SIZE);
    }
    CHECK(buffer_.size() >= MAX_PACKET_SIZE);
    message.data = buffer_.as_slice().truncate(MAX_PACKET_SIZE);
  }

  UdpMessage extract_udp_message(UdpSocketFd::InboundMessage &message) {
    message_.data = buffer_.from_slice(message.data);
    auto size = message_.data.size();
    size = (size + 7) & ~7;
    CHECK(size <= MAX_PACKET_SIZE);
    buffer_.confirm_read(size);
    return std::move(message_);
  }

 private:
  enum : size_t { MAX_PACKET_SIZE = 2048, RESERVED_SIZE = MAX_PACKET_SIZE * 8 };
  UdpMessage message_;
  BufferSlice buffer_;
};

// One for thread is enough
class UdpReader {
 public:
  UdpReader() {
    for (size_t i = 0; i < messages_.size(); i++) {
      helpers_[i].init_inbound_message(messages_[i]);
    }
  }
  Status read_once(UdpSocketFd &fd, VectorQueue<UdpMessage> &queue) TD_WARN_UNUSED_RESULT {
    for (size_t i = 0; i < messages_.size(); i++) {
      CHECK(messages_[i].data.size() == 2048);
    }
    size_t cnt = 0;
    auto status = fd.receive_messages(messages_, cnt);
    for (size_t i = 0; i < cnt; i++) {
      queue.push(helpers_[i].extract_udp_message(messages_[i]));
      helpers_[i].init_inbound_message(messages_[i]);
    }
    for (size_t i = cnt; i < messages_.size(); i++) {
      LOG_CHECK(messages_[i].data.size() == 2048)
          << " cnt = " << cnt << " i = " << i << " size = " << messages_[i].data.size() << " status = " << status;
    }
    if (status.is_error() && !UdpSocketFd::is_critical_read_error(status)) {
      queue.push(UdpMessage{{}, {}, std::move(status)});
    }
    return status;
  }

 private:
  enum : size_t { BUFFER_SIZE = 16 };
  std::array<UdpSocketFd::InboundMessage, BUFFER_SIZE> messages_;
  std::array<UdpReaderHelper, BUFFER_SIZE> helpers_;
};

}  // namespace detail

#endif

class BufferedUdp : public UdpSocketFd {
 public:
  explicit BufferedUdp(UdpSocketFd fd) : UdpSocketFd(std::move(fd)) {
  }

#if TD_PORT_POSIX
  Result<optional<UdpMessage>> receive() {
    if (input_.empty() && can_read(*this)) {
      TRY_STATUS(flush_read_once());
    }
    if (input_.empty()) {
      return optional<UdpMessage>();
    }
    return input_.pop();
  }

  void send(UdpMessage message) {
    output_.push(std::move(message));
  }

  Status flush_send() {
    Status status;
    while (status.is_ok() && can_write(*this) && !output_.empty()) {
      status = flush_send_once();
    }
    return status;
  }
#endif

  UdpSocketFd move_as_udp_socket_fd() {
    return std::move(as_fd());
  }

  UdpSocketFd &as_fd() {
    return *static_cast<UdpSocketFd *>(this);
  }

 private:
#if TD_PORT_POSIX
  VectorQueue<UdpMessage> input_;
  VectorQueue<UdpMessage> output_;

  VectorQueue<UdpMessage> &input() {
    return input_;
  }
  VectorQueue<UdpMessage> &output() {
    return output_;
  }

  Status flush_send_once() TD_WARN_UNUSED_RESULT {
    return detail::UdpWriter::write_once(as_fd(), output_);
  }

  Status flush_read_once() TD_WARN_UNUSED_RESULT {
    init_thread_local<detail::UdpReader>(udp_reader_);
    return udp_reader_->read_once(as_fd(), input_);
  }

  static TD_THREAD_LOCAL detail::UdpReader *udp_reader_;
#endif
};

}  // namespace td
