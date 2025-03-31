//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/TcpListener.h"

#include "td/utils/logging.h"
#include "td/utils/port/detail/PollableFd.h"

namespace td {

TcpListener::TcpListener(int port, ActorShared<Callback> callback, Slice server_address)
    : port_(port), callback_(std::move(callback)), server_address_(server_address.str()) {
}

void TcpListener::hangup() {
  stop();
}

void TcpListener::start_up() {
  auto r_socket = ServerSocketFd::open(port_, server_address_);
  if (r_socket.is_error()) {
    LOG(ERROR) << "Can't open server socket: " << r_socket.error();
    set_timeout_in(5);
    return;
  }
  server_fd_ = r_socket.move_as_ok();
  Scheduler::subscribe(server_fd_.get_poll_info().extract_pollable_fd(this));
}

void TcpListener::tear_down() {
  if (!server_fd_.empty()) {
    Scheduler::unsubscribe_before_close(server_fd_.get_poll_info().get_pollable_fd_ref());
    server_fd_.close();
  }
}

void TcpListener::loop() {
  if (server_fd_.empty()) {
    start_up();
    if (server_fd_.empty()) {
      return;
    }
  }
  sync_with_poll(server_fd_);
  while (can_read_local(server_fd_)) {
    auto r_socket_fd = server_fd_.accept();
    if (r_socket_fd.is_error()) {
      if (r_socket_fd.error().code() != -1) {
        LOG(ERROR) << r_socket_fd.error();
      }
      continue;
    }
    send_closure(callback_, &Callback::accept, r_socket_fd.move_as_ok());
  }

  if (can_close_local(server_fd_)) {
    stop();
  }
}

}  // namespace td
