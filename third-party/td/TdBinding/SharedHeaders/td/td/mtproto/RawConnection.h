//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/ConnectionManager.h"
#include "td/mtproto/PacketInfo.h"
#include "td/mtproto/TransportType.h"

#include "td/utils/buffer.h"
#include "td/utils/BufferedFd.h"
#include "td/utils/common.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Status.h"
#include "td/utils/StorerBase.h"

namespace td {
namespace mtproto {

class AuthKey;

class RawConnection {
 public:
  class StatsCallback {
   public:
    virtual ~StatsCallback() = default;
    virtual void on_read(uint64 bytes) = 0;
    virtual void on_write(uint64 bytes) = 0;

    virtual void on_pong() = 0;   // called when we know that connection is alive
    virtual void on_error() = 0;  // called on RawConnection error. Such error should be very rare on good connections.
    virtual void on_mtproto_error() = 0;
  };
  RawConnection() = default;
  RawConnection(const RawConnection &) = delete;
  RawConnection &operator=(const RawConnection &) = delete;
  virtual ~RawConnection();

  static unique_ptr<RawConnection> create(IPAddress ip_address, BufferedFd<SocketFd> buffered_socket_fd,
                                          TransportType transport_type, unique_ptr<StatsCallback> stats_callback);

  virtual void set_connection_token(ConnectionManager::ConnectionToken connection_token) = 0;

  virtual bool can_send() const = 0;
  virtual TransportType get_transport_type() const = 0;
  virtual size_t send_crypto(const Storer &storer, uint64 session_id, int64 salt, const AuthKey &auth_key,
                             uint64 quick_ack_token) = 0;
  virtual void send_no_crypto(const Storer &storer) = 0;

  virtual PollableFdInfo &get_poll_info() = 0;
  virtual StatsCallback *stats_callback() = 0;

  class Callback {
   public:
    Callback() = default;
    Callback(const Callback &) = delete;
    Callback &operator=(const Callback &) = delete;
    virtual ~Callback() = default;
    virtual Status on_raw_packet(const PacketInfo &packet_info, BufferSlice packet) = 0;
    virtual Status on_quick_ack(uint64 quick_ack_token) {
      return Status::Error("Quick acknowledgements aren't supported by the callback");
    }
    virtual Status before_write() {
      return Status::OK();
    }
    virtual void on_read(size_t size) {
    }
  };

  // NB: After first returned error, all subsequent calls will return error too.
  virtual Status flush(const AuthKey &auth_key, Callback &callback) TD_WARN_UNUSED_RESULT = 0;
  virtual bool has_error() const = 0;

  virtual void close() = 0;

  struct PublicFields {
    uint32 extra{0};
    string debug_str;
    double rtt{0};
  };

  virtual PublicFields &extra() = 0;
  virtual const PublicFields &extra() const = 0;
};

}  // namespace mtproto
}  // namespace td
