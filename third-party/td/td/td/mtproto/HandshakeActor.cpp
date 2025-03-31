//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/mtproto/HandshakeActor.h"

#include "td/mtproto/HandshakeConnection.h"

#include "td/utils/common.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

namespace td {
namespace mtproto {

HandshakeActor::HandshakeActor(unique_ptr<AuthKeyHandshake> handshake, unique_ptr<RawConnection> raw_connection,
                               unique_ptr<AuthKeyHandshakeContext> context, double timeout,
                               Promise<unique_ptr<RawConnection>> raw_connection_promise,
                               Promise<unique_ptr<AuthKeyHandshake>> handshake_promise)
    : handshake_(std::move(handshake))
    , connection_(make_unique<HandshakeConnection>(std::move(raw_connection), handshake_.get(), std::move(context)))
    , timeout_(timeout)
    , raw_connection_promise_(std::move(raw_connection_promise))
    , handshake_promise_(std::move(handshake_promise)) {
}

void HandshakeActor::close() {
  finish(Status::Error("Canceled"));
  stop();
}

void HandshakeActor::start_up() {
  Scheduler::subscribe(connection_->get_poll_info().extract_pollable_fd(this));
  set_timeout_in(timeout_);
  handshake_->set_timeout_in(timeout_);
  yield();
}

void HandshakeActor::loop() {
  auto status = connection_->flush();
  if (status.is_error()) {
    finish(std::move(status));
    return stop();
  }
  if (handshake_->is_ready_for_finish()) {
    finish(Status::OK());
    return stop();
  }
}

void HandshakeActor::hangup() {
  finish(Status::Error(1, "Canceled"));
  stop();
}

void HandshakeActor::timeout_expired() {
  finish(Status::Error("Timeout expired"));
  stop();
}

void HandshakeActor::tear_down() {
  finish(Status::OK());
}

void HandshakeActor::finish(Status status) {
  // NB: order may be important for parent
  return_connection(std::move(status));
  return_handshake();
}

void HandshakeActor::return_connection(Status status) {
  auto raw_connection = connection_->move_as_raw_connection();
  if (!raw_connection) {
    CHECK(!raw_connection_promise_);
    return;
  }
  if (status.is_error() && !raw_connection->extra().debug_str.empty()) {
    status = status.move_as_error_suffix(PSLICE() << " : " << raw_connection->extra().debug_str);
  }
  Scheduler::unsubscribe(raw_connection->get_poll_info().get_pollable_fd_ref());
  if (raw_connection_promise_) {
    if (status.is_error()) {
      if (raw_connection->stats_callback()) {
        raw_connection->stats_callback()->on_error();
      }
      raw_connection->close();
      raw_connection_promise_.set_error(std::move(status));
    } else {
      if (raw_connection->stats_callback()) {
        raw_connection->stats_callback()->on_pong();
      }
      raw_connection_promise_.set_value(std::move(raw_connection));
    }
  } else {
    if (raw_connection->stats_callback()) {
      raw_connection->stats_callback()->on_error();
    }
    raw_connection->close();
  }
}

void HandshakeActor::return_handshake() {
  if (!handshake_promise_) {
    CHECK(!handshake_);
    return;
  }
  handshake_promise_.set_value(std::move(handshake_));
}

}  // namespace mtproto
}  // namespace td
