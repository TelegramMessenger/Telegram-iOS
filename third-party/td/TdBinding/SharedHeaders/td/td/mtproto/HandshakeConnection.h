//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/AuthKey.h"
#include "td/mtproto/Handshake.h"
#include "td/mtproto/MessageId.h"
#include "td/mtproto/NoCryptoStorer.h"
#include "td/mtproto/PacketInfo.h"
#include "td/mtproto/PacketStorer.h"
#include "td/mtproto/RawConnection.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/Status.h"
#include "td/utils/StorerBase.h"

namespace td {
namespace mtproto {

class HandshakeConnection final
    : private RawConnection::Callback
    , private AuthKeyHandshake::Callback {
 public:
  HandshakeConnection(unique_ptr<RawConnection> raw_connection, AuthKeyHandshake *handshake,
                      unique_ptr<AuthKeyHandshakeContext> context)
      : raw_connection_(std::move(raw_connection)), handshake_(handshake), context_(std::move(context)) {
    handshake_->resume(this);
  }

  PollableFdInfo &get_poll_info() {
    return raw_connection_->get_poll_info();
  }

  unique_ptr<RawConnection> move_as_raw_connection() {
    return std::move(raw_connection_);
  }

  void close() {
    raw_connection_->close();
  }

  Status flush() {
    auto status = raw_connection_->flush(AuthKey(), *this);
    if (status.code() == -404) {
      LOG(WARNING) << "Clear handshake " << tag("error", status);
      handshake_->clear();
    }
    return status;
  }

 private:
  unique_ptr<RawConnection> raw_connection_;
  AuthKeyHandshake *handshake_;
  unique_ptr<AuthKeyHandshakeContext> context_;

  void send_no_crypto(const Storer &storer) final {
    raw_connection_->send_no_crypto(PacketStorer<NoCryptoImpl>(MessageId(), storer));
  }

  Status on_raw_packet(const PacketInfo &packet_info, BufferSlice packet) final {
    if (!packet_info.no_crypto_flag) {
      return Status::Error("Expected not encrypted packet");
    }

    // skip header
    if (packet.size() < 12) {
      return Status::Error("Result is too small");
    }
    packet.confirm_read(12);

    auto fixed_packet_size = packet.size() & ~3;  // remove some padded data
    TRY_STATUS(handshake_->on_message(packet.as_slice().truncate(fixed_packet_size), this, context_.get()));
    return Status::OK();
  }
};

}  // namespace mtproto
}  // namespace td
