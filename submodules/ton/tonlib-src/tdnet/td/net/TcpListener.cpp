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
#include "td/net/TcpListener.h"

namespace td {
TcpListener::TcpListener(int port, std::unique_ptr<Callback> callback) : port_(port), callback_(std::move(callback)) {
}
void TcpListener::notify() {
  td::actor::send_closure_later(self_, &TcpListener::on_net);
}
void TcpListener::on_net() {
  loop();
}

void TcpListener::start_up() {
  self_ = actor_id(this);

  auto r_socket = td::ServerSocketFd::open(port_);
  if (r_socket.is_error()) {
    LOG(ERROR) << r_socket.error();
    return stop();
  }

  server_socket_fd_ = r_socket.move_as_ok();

  // Subscribe for socket updates
  // NB: Interface will be changed
  td::actor::SchedulerContext::get()->get_poll().subscribe(server_socket_fd_.get_poll_info().extract_pollable_fd(this),
                                                           PollFlags::Read());
}

void TcpListener::tear_down() {
  // unsubscribe from socket updates
  // nb: interface will be changed
  td::actor::SchedulerContext::get()->get_poll().unsubscribe(server_socket_fd_.get_poll_info().get_pollable_fd_ref());
}

void TcpListener::loop() {
  auto status = [&] {
    while (td::can_read(server_socket_fd_)) {
      auto r_socket = server_socket_fd_.accept();
      if (r_socket.is_error() && r_socket.error().code() == -1) {
        break;
      }
      TRY_RESULT(client_socket, std::move(r_socket));
      LOG(ERROR) << "Accept";
      callback_->accept(std::move(client_socket));
    }
    if (td::can_close(server_socket_fd_)) {
      stop();
    }
    return td::Status::OK();
  }();

  if (status.is_error()) {
    LOG(ERROR) << "Server error " << status;
    return stop();
  }
}
TcpInfiniteListener::TcpInfiniteListener(int32 port, std::unique_ptr<TcpListener::Callback> callback)
    : port_(port), callback_(std::move(callback)) {
}

void TcpInfiniteListener::start_up() {
  loop();
}

void TcpInfiniteListener::hangup() {
  close_flag_ = true;
  tcp_listener_.reset();
  if (refcnt_ == 0) {
    stop();
  }
}

void TcpInfiniteListener::loop() {
  if (!tcp_listener_.empty()) {
    return;
  }
  class Callback : public TcpListener::Callback {
   public:
    Callback(actor::ActorShared<TcpInfiniteListener> parent) : parent_(std::move(parent)) {
    }
    void accept(SocketFd fd) override {
      actor::send_closure(parent_, &TcpInfiniteListener::accept, std::move(fd));
    }

   private:
    actor::ActorShared<TcpInfiniteListener> parent_;
  };
  refcnt_++;
  tcp_listener_ = actor::create_actor<TcpListener>(
      actor::ActorOptions().with_name(PSLICE() << "TcpListener" << tag("port", port_)).with_poll(), port_,
      std::make_unique<Callback>(actor_shared(this)));
}

void TcpInfiniteListener::accept(SocketFd fd) {
  callback_->accept(std::move(fd));
}

void TcpInfiniteListener::hangup_shared() {
  refcnt_--;
  tcp_listener_.reset();
  if (close_flag_) {
    if (refcnt_ == 0) {
      stop();
    }
  } else {
    alarm_timestamp() = Timestamp::in(5 /*5 seconds*/);
  }
}

}  // namespace td
