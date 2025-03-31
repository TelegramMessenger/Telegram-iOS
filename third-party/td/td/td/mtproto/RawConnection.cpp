//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/RawConnection.h"

#include "td/mtproto/AuthKey.h"
#include "td/mtproto/IStreamTransport.h"
#include "td/mtproto/ProxySecret.h"
#include "td/mtproto/Transport.h"

#if TD_DARWIN_WATCH_OS
#include "td/net/DarwinHttp.h"
#endif

#include "td/utils/FlatHashMap.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/MpscPollableQueue.h"
#include "td/utils/port/EventFd.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"
#include "td/utils/StorerBase.h"

#include <memory>
#include <utility>

namespace td {
namespace mtproto {

RawConnection::~RawConnection() {
  LOG(DEBUG) << "Destroy raw connection " << this;
}

class RawConnectionDefault final : public RawConnection {
 public:
  RawConnectionDefault(BufferedFd<SocketFd> buffered_socket_fd, TransportType transport_type,
                       unique_ptr<StatsCallback> stats_callback)
      : socket_fd_(std::move(buffered_socket_fd))
      , transport_(create_transport(std::move(transport_type)))
      , stats_callback_(std::move(stats_callback)) {
    LOG(DEBUG) << "Create raw connection " << this;
    transport_->init(&socket_fd_.input_buffer(), &socket_fd_.output_buffer());
  }

  void set_connection_token(ConnectionManager::ConnectionToken connection_token) final {
    connection_token_ = std::move(connection_token);
  }

  bool can_send() const final {
    return transport_->can_write();
  }

  TransportType get_transport_type() const final {
    return transport_->get_type();
  }

  size_t send_crypto(const Storer &storer, uint64 session_id, int64 salt, const AuthKey &auth_key,
                     uint64 quick_ack_token) final {
    PacketInfo packet_info;
    packet_info.version = 2;
    packet_info.no_crypto_flag = false;
    packet_info.salt = salt;
    packet_info.session_id = session_id;
    packet_info.use_random_padding = transport_->use_random_padding();
    auto packet =
        Transport::write(storer, auth_key, &packet_info, transport_->max_prepend_size(), transport_->max_append_size());

    bool use_quick_ack = false;
    if (quick_ack_token != 0 && transport_->support_quick_ack()) {
      CHECK(packet_info.message_ack & (1u << 31));
      auto tmp = quick_ack_to_token_.emplace(packet_info.message_ack, quick_ack_token);
      if (tmp.second) {
        use_quick_ack = true;
      } else {
        LOG(ERROR) << "Quick ack " << packet_info.message_ack << " collision";
      }
    }

    auto packet_size = packet.size();
    transport_->write(std::move(packet), use_quick_ack);
    return packet_size;
  }

  void send_no_crypto(const Storer &storer) final {
    PacketInfo packet_info;
    packet_info.no_crypto_flag = true;
    auto packet = Transport::write(storer, AuthKey(), &packet_info, transport_->max_prepend_size(),
                                   transport_->max_append_size());

    LOG(INFO) << "Send handshake packet: " << format::as_hex_dump<4>(packet.as_slice());
    transport_->write(std::move(packet), false);
  }

  PollableFdInfo &get_poll_info() final {
    return socket_fd_.get_poll_info();
  }

  StatsCallback *stats_callback() final {
    return stats_callback_.get();
  }

  // NB: After first returned error, all subsequent calls will return error too.
  Status flush(const AuthKey &auth_key, Callback &callback) final {
    auto status = do_flush(auth_key, callback);
    if (status.is_error()) {
      if (stats_callback_ && status.code() != 2) {
        stats_callback_->on_error();
      }
      has_error_ = true;
    }
    return status;
  }

  bool has_error() const final {
    return has_error_;
  }

  void close() final {
    LOG(DEBUG) << "Close raw connection " << this;
    transport_.reset();
    socket_fd_.close();
  }

  PublicFields &extra() final {
    return extra_;
  }
  const PublicFields &extra() const final {
    return extra_;
  }

 private:
  PublicFields extra_;
  BufferedFd<SocketFd> socket_fd_;
  unique_ptr<IStreamTransport> transport_;
  FlatHashMap<uint32, uint64> quick_ack_to_token_;
  bool has_error_{false};

  unique_ptr<StatsCallback> stats_callback_;

  ConnectionManager::ConnectionToken connection_token_;

  void on_read(size_t size, Callback &callback) {
    if (size <= 0) {
      return;
    }

    if (stats_callback_) {
      stats_callback_->on_read(size);
    }
    callback.on_read(size);
  }

  Status flush_read(const AuthKey &auth_key, Callback &callback) {
    auto r = socket_fd_.flush_read();
    if (r.is_ok()) {
      on_read(r.ok(), callback);
    }
    while (transport_->can_read()) {
      BufferSlice packet;
      uint32 quick_ack = 0;
      TRY_RESULT(wait_size, transport_->read_next(&packet, &quick_ack));
      if (wait_size != 0) {
        constexpr size_t MAX_PACKET_SIZE = (1 << 22) + 1024;
        if (wait_size > MAX_PACKET_SIZE) {
          return Status::Error(PSLICE() << "Expected packet size is too big: " << wait_size);
        }
        break;
      }
      if (quick_ack != 0) {
        TRY_STATUS(on_quick_ack(quick_ack, callback));
        continue;
      }

      auto old_pointer = packet.as_slice().ubegin();
      if (!is_aligned_pointer<4>(old_pointer)) {
        BufferSlice new_packet(packet.size());
        new_packet.as_mutable_slice().copy_from(packet.as_slice());
        packet = std::move(new_packet);
      }
      LOG_CHECK(is_aligned_pointer<4>(packet.as_slice().ubegin()))
          << old_pointer << ' ' << packet.as_slice().ubegin() << ' ' << BufferSlice(0).as_slice().ubegin() << ' '
          << packet.size() << ' ' << wait_size << ' ' << quick_ack;

      PacketInfo packet_info;
      packet_info.version = 2;

      TRY_RESULT(read_result, Transport::read(packet.as_mutable_slice(), auth_key, &packet_info));
      switch (read_result.type()) {
        case Transport::ReadResult::Quickack:
          TRY_STATUS(on_quick_ack(read_result.quick_ack(), callback));
          break;
        case Transport::ReadResult::Error:
          TRY_STATUS(on_read_mtproto_error(read_result.error()));
          break;
        case Transport::ReadResult::Packet:
          // If a packet was successfully decrypted, then it is ok to assume that the connection is alive
          if (!auth_key.empty()) {
            if (stats_callback_) {
              stats_callback_->on_pong();
            }
          }

          TRY_STATUS(callback.on_raw_packet(packet_info, packet.from_slice(read_result.packet())));
          break;
        case Transport::ReadResult::Nop:
          break;
        default:
          UNREACHABLE();
      }
    }

    TRY_STATUS(std::move(r));
    return Status::OK();
  }

  Status on_read_mtproto_error(int32 error_code) {
    if (error_code == -429) {
      if (stats_callback_) {
        stats_callback_->on_mtproto_error();
      }
      return Status::Error(500, PSLICE() << "MTProto error: " << error_code);
    }
    if (error_code == -404) {
      return Status::Error(-404, PSLICE() << "MTProto error: " << error_code);
    }
    return Status::Error(PSLICE() << "MTProto error: " << error_code);
  }

  Status on_quick_ack(uint32 quick_ack, Callback &callback) {
    if ((quick_ack & (1u << 31)) == 0) {
      LOG(ERROR) << "Receive invalid quick_ack " << quick_ack;
      return Status::OK();
    }

    auto it = quick_ack_to_token_.find(quick_ack);
    if (it == quick_ack_to_token_.end()) {
      LOG(WARNING) << "Receive unknown quick_ack " << quick_ack;
      return Status::OK();
    }
    auto token = it->second;
    quick_ack_to_token_.erase(it);
    callback.on_quick_ack(token).ignore();
    return Status::OK();
  }

  Status flush_write() {
    TRY_RESULT(size, socket_fd_.flush_write());
    if (size > 0 && stats_callback_) {
      stats_callback_->on_write(size);
    }
    return Status::OK();
  }

  Status do_flush(const AuthKey &auth_key, Callback &callback) TD_WARN_UNUSED_RESULT {
    if (has_error_) {
      return Status::Error("Connection has already failed");
    }
    sync_with_poll(socket_fd_);

    // read/write
    // EINVAL can be returned in Linux kernel < 2.6.28. And on some new kernels too.
    // just close connection and hope that read or write will not return this error too.
    TRY_STATUS(socket_fd_.get_pending_error());

    TRY_STATUS(flush_read(auth_key, callback));
    TRY_STATUS(callback.before_write());
    TRY_STATUS(flush_write());
    if (can_close_local(socket_fd_)) {
      return Status::Error("Connection closed");
    }
    return Status::OK();
  }
};

#if TD_DARWIN_WATCH_OS
class RawConnectionHttp final : public RawConnection {
 public:
  RawConnectionHttp(IPAddress ip_address, unique_ptr<StatsCallback> stats_callback)
      : ip_address_(std::move(ip_address)), stats_callback_(std::move(stats_callback)) {
    LOG(DEBUG) << "Create raw connection " << this;
    answers_ = std::make_shared<MpscPollableQueue<Result<BufferSlice>>>();
    answers_->init();
  }

  void set_connection_token(ConnectionManager::ConnectionToken connection_token) final {
    connection_token_ = std::move(connection_token);
  }

  bool can_send() const final {
    return mode_ == Send;
  }

  TransportType get_transport_type() const final {
    return mtproto::TransportType{mtproto::TransportType::Http, 0, mtproto::ProxySecret()};
  }

  size_t send_crypto(const Storer &storer, uint64 session_id, int64 salt, const AuthKey &auth_key,
                     uint64 quick_ack_token) final {
    PacketInfo packet_info;
    packet_info.version = 2;
    packet_info.no_crypto_flag = false;
    packet_info.salt = salt;
    packet_info.session_id = session_id;
    packet_info.use_random_padding = false;
    auto packet = Transport::write(storer, auth_key, &packet_info);

    auto packet_size = packet.size();
    send_packet(packet.as_buffer_slice());
    return packet_size;
  }

  void send_no_crypto(const Storer &storer) final {
    PacketInfo packet_info;
    packet_info.no_crypto_flag = true;
    auto packet = Transport::write(storer, AuthKey(), &packet_info);

    LOG(INFO) << "Send handshake packet: " << format::as_hex_dump<4>(packet.as_slice());
    send_packet(packet.as_buffer_slice());
  }

  PollableFdInfo &get_poll_info() final {
    return answers_->reader_get_event_fd().get_poll_info();
  }

  StatsCallback *stats_callback() final {
    return stats_callback_.get();
  }

  // NB: After first returned error, all subsequent calls will return error too.
  Status flush(const AuthKey &auth_key, Callback &callback) final {
    auto status = do_flush(auth_key, callback);
    if (status.is_error()) {
      if (stats_callback_ && status.code() != 2) {
        stats_callback_->on_error();
      }
      has_error_ = true;
    }
    return status;
  }

  bool has_error() const final {
    return has_error_;
  }

  void close() final {
    LOG(DEBUG) << "Close raw connection " << this;
  }

  PublicFields &extra() final {
    return extra_;
  }
  const PublicFields &extra() const final {
    return extra_;
  }

 private:
  PublicFields extra_;
  IPAddress ip_address_;
  bool has_error_{false};
  EventFd event_fd_;

  enum Mode { Send, Receive } mode_{Send};

  unique_ptr<StatsCallback> stats_callback_;

  ConnectionManager::ConnectionToken connection_token_;
  std::shared_ptr<MpscPollableQueue<Result<BufferSlice>>> answers_;
  std::vector<BufferSlice> to_send_;

  void on_read(size_t size, Callback &callback) {
    if (size <= 0) {
      return;
    }

    if (stats_callback_) {
      stats_callback_->on_read(size);
    }
    callback.on_read(size);
  }

  void send_packet(BufferSlice packet) {
    CHECK(mode_ == Send);
    mode_ = Receive;
    to_send_.push_back(std::move(packet));
  }

  Status flush_read(const AuthKey &auth_key, Callback &callback) {
    while (true) {
      auto packets_n = answers_->reader_wait_nonblock();
      if (packets_n == 0) {
        break;
      }
      for (int i = 0; i < packets_n; i++) {
        TRY_RESULT(packet, answers_->reader_get_unsafe());
        on_read(packet.size(), callback);
        CHECK(mode_ == Receive);
        mode_ = Send;

        PacketInfo packet_info;
        packet_info.version = 2;

        TRY_RESULT(read_result, Transport::read(packet.as_mutable_slice(), auth_key, &packet_info));
        switch (read_result.type()) {
          case Transport::ReadResult::Quickack: {
            break;
          }
          case Transport::ReadResult::Error: {
            TRY_STATUS(on_read_mtproto_error(read_result.error()));
            break;
          }
          case Transport::ReadResult::Packet: {
            // If a packet was successfully decrypted, then it is ok to assume that the connection is alive
            if (!auth_key.empty()) {
              if (stats_callback_) {
                stats_callback_->on_pong();
              }
            }

            TRY_STATUS(callback.on_raw_packet(packet_info, packet.from_slice(read_result.packet())));
            break;
          }
          case Transport::ReadResult::Nop:
            break;
          default:
            UNREACHABLE();
        }
      }
    }

    return Status::OK();
  }

  Status on_read_mtproto_error(int32 error_code) {
    if (error_code == -429) {
      if (stats_callback_) {
        stats_callback_->on_mtproto_error();
      }
      return Status::Error(500, PSLICE() << "MTProto error: " << error_code);
    }
    if (error_code == -404) {
      return Status::Error(-404, PSLICE() << "MTProto error: " << error_code);
    }
    return Status::Error(PSLICE() << "MTProto error: " << error_code);
  }

  Status flush_write() {
    for (auto &packet : to_send_) {
      TRY_STATUS(do_send(packet.as_slice()));
      if (packet.size() > 0 && stats_callback_) {
        stats_callback_->on_write(packet.size());
      }
    }
    to_send_.clear();
    return Status::OK();
  }

  Status do_send(Slice data) {
    DarwinHttp::post(PSLICE() << "http://" << ip_address_.get_ip_host() << ":" << ip_address_.get_port() << "/api",
                     data, [answers = answers_](auto res) { answers->writer_put(std::move(res)); });
    return Status::OK();
  }

  Status do_flush(const AuthKey &auth_key, Callback &callback) TD_WARN_UNUSED_RESULT {
    if (has_error_) {
      return Status::Error("Connection has already failed");
    }

    TRY_STATUS(flush_read(auth_key, callback));
    TRY_STATUS(callback.before_write());
    TRY_STATUS(flush_write());
    return Status::OK();
  }
};
#endif

unique_ptr<RawConnection> RawConnection::create(IPAddress ip_address, BufferedFd<SocketFd> buffered_socket_fd,
                                                TransportType transport_type,
                                                unique_ptr<StatsCallback> stats_callback) {
#if TD_DARWIN_WATCH_OS
  return td::make_unique<RawConnectionHttp>(std::move(ip_address), std::move(stats_callback));
#else
  return td::make_unique<RawConnectionDefault>(std::move(buffered_socket_fd), std::move(transport_type),
                                               std::move(stats_callback));
#endif
}

}  // namespace mtproto
}  // namespace td
