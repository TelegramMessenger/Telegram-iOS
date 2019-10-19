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

#include "td/actor/actor.h"

#include "td/utils/port/ServerSocketFd.h"
#include "td/utils/Observer.h"

namespace td {
class TcpListener : public td::actor::Actor, private td::ObserverBase {
 public:
  class Callback {
   public:
    virtual ~Callback() = default;
    virtual void accept(SocketFd fd) = 0;
  };

  TcpListener(int port, std::unique_ptr<Callback> callback);

 private:
  int port_;
  std::unique_ptr<Callback> callback_;
  td::ServerSocketFd server_socket_fd_;
  td::actor::ActorId<TcpListener> self_;

  void notify() override;
  void on_net();

  void start_up() override;

  void tear_down() override;

  void loop() override;
};

class TcpInfiniteListener : public actor::Actor {
 public:
  TcpInfiniteListener(int32 port, std::unique_ptr<TcpListener::Callback> callback);

 private:
  int32 port_;
  std::unique_ptr<TcpListener::Callback> callback_;
  actor::ActorOwn<TcpListener> tcp_listener_;
  int32 refcnt_{0};
  bool close_flag_{false};

  void start_up() override;

  void hangup() override;
  void loop() override;
  void accept(SocketFd fd);
  void hangup_shared() override;
};
}  // namespace td
