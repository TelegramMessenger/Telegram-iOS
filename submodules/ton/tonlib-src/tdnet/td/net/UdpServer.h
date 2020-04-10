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

#include "td/actor/actor.h"
#include "td/utils/BufferedUdp.h"

#include "td/utils/port/UdpSocketFd.h"

namespace td {

class UdpServer : public td::actor::Actor {
 public:
  class Callback {
   public:
    virtual ~Callback() = default;
    virtual void on_udp_message(td::UdpMessage udp_message) = 0;
  };
  virtual void send(td::UdpMessage &&message) = 0;

  static Result<actor::ActorOwn<UdpServer>> create(td::Slice name, int32 port, std::unique_ptr<Callback> callback);
  static Result<actor::ActorOwn<UdpServer>> create_via_tcp(td::Slice name, int32 port,
                                                           std::unique_ptr<Callback> callback);
};

}  // namespace td
