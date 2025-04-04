//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/net/TransparentProxy.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {
namespace mtproto {

class Grease {
 public:
  static void init(MutableSlice res);
};

class TlsInit final : public TransparentProxy {
 public:
  TlsInit(SocketFd socket_fd, string domain, string secret, unique_ptr<Callback> callback, ActorShared<> parent,
          double server_time_difference)
      : TransparentProxy(std::move(socket_fd), IPAddress(), std::move(domain), std::move(secret), std::move(callback),
                         std::move(parent))
      , server_time_difference_(server_time_difference) {
  }

 private:
  double server_time_difference_{0};
  enum class State {
    SendHello,
    WaitHelloResponse,
  } state_ = State::SendHello;
  std::string hello_rand_;

  void send_hello();
  Status wait_hello_response();

  Status loop_impl() final;
};

}  // namespace mtproto
}  // namespace td
