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

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "td/net/TcpListener.h"
#include "td/utils/crypto.h"
#include "td/utils/BufferedFd.h"
#include "tl-utils/tl-utils.hpp"
#include "td/utils/Random.h"
#include "common/errorcode.h"

#include <map>
#include <set>

namespace ton {

namespace adnl {

class AdnlExtConnection : public td::actor::Actor, public td::ObserverBase {
 public:
  class Callback {
   public:
    virtual ~Callback() = default;
    virtual void on_close(td::actor::ActorId<AdnlExtConnection> conn) = 0;
    virtual void on_ready(td::actor::ActorId<AdnlExtConnection> conn) = 0;
  };

  double timeout() {
    return is_client_ ? 20.0 : 60.0;
  }

  AdnlExtConnection(td::SocketFd fd, std::unique_ptr<Callback> callback, bool is_client)
      : buffered_fd_(std::move(fd)), callback_(std::move(callback)), is_client_(is_client) {
  }
  void send(td::BufferSlice data);
  void send_uninit(td::BufferSlice data);
  td::Status receive(td::ChainBufferReader &input, bool &exit_loop);
  virtual td::Status process_packet(td::BufferSlice data) = 0;
  td::Status receive_packet(td::BufferSlice data);
  virtual td::Status process_custom_packet(td::BufferSlice &data, bool &processed) = 0;
  virtual td::Status process_init_packet(td::BufferSlice data) = 0;
  virtual bool authorized() const {
    return false;
  }
  td::Status init_crypto(td::Slice data);
  void stop_read() {
    stop_read_ = true;
  }
  void resume_read() {
    stop_read_ = false;
  }
  bool check_ready() const {
    return received_bytes_ && inited_ && authorized() && !td::can_close(buffered_fd_);
  }
  void check_ready_async(td::Promise<td::Unit> promise) {
    if (check_ready()) {
      promise.set_value(td::Unit());
    } else {
      promise.set_error(td::Status::Error(ErrorCode::notready, "not ready"));
    }
  }
  void send_ready() {
    if (check_ready() && !sent_ready_ && callback_) {
      callback_->on_ready(actor_id(this));
      sent_ready_ = true;
    }
  }

 protected:
  td::BufferedFd<td::SocketFd> buffered_fd_;
  td::actor::ActorId<AdnlExtConnection> self_;
  std::unique_ptr<Callback> callback_;
  bool sent_ready_ = false;
  bool is_client_;

  void notify() override {
    // NB: Interface will be changed
    td::actor::send_closure_later(self_, &AdnlExtConnection::on_net);
  }

  void start_up() override {
    self_ = actor_id(this);
    // Subscribe for socket updates
    // NB: Interface will be changed
    td::actor::SchedulerContext::get()->get_poll().subscribe(buffered_fd_.get_poll_info().extract_pollable_fd(this),
                                                             td::PollFlags::ReadWrite());
    update_timer();
    notify();
  }

 private:
  td::AesCtrState in_ctr_;
  td::AesCtrState out_ctr_;
  bool inited_ = false;
  bool stop_read_ = false;
  bool read_len_ = false;
  td::uint32 len_;
  td::uint32 received_bytes_ = 0;
  td::Timestamp fail_at_;
  td::Timestamp send_ping_at_;
  bool ping_sent_ = false;

  void on_net() {
    loop();
  }

  void tear_down() override {
    if (callback_) {
      callback_->on_close(actor_id(this));
      callback_ = nullptr;
    }
    // unsubscribe from socket updates
    // nb: interface will be changed
    td::actor::SchedulerContext::get()->get_poll().unsubscribe(buffered_fd_.get_poll_info().get_pollable_fd_ref());
  }

  void update_timer() {
    fail_at_ = td::Timestamp::in(timeout());
    alarm_timestamp() = fail_at_;
    if (is_client_) {
      ping_sent_ = false;
      send_ping_at_ = td::Timestamp::in(timeout() / 2);
      alarm_timestamp().relax(send_ping_at_);
    }
  }

  void loop() override;

  void alarm() override {
    alarm_timestamp() = fail_at_;
    if (fail_at_.is_in_past()) {
      stop();
    } else if (is_client_ && !ping_sent_) {
      if (send_ping_at_.is_in_past()) {
        auto obj = create_tl_object<ton_api::tcp_ping>(td::Random::fast_uint64());
        send(serialize_tl_object(obj, true));
        ping_sent_ = true;
      } else {
        alarm_timestamp().relax(send_ping_at_);
      }
    }
  }
};

}  // namespace adnl

}  // namespace ton
