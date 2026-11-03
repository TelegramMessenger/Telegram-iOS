//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/actor.h"

#include "td/utils/BufferedFd.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Status.h"

namespace td {

extern int VERBOSITY_NAME(proxy);

class TransparentProxy : public Actor {
 public:
  class Callback {
   public:
    Callback() = default;
    Callback(const Callback &) = delete;
    Callback &operator=(const Callback &) = delete;
    virtual ~Callback() = default;

    virtual void set_result(Result<BufferedFd<SocketFd>> r_buffered_socket_fd) = 0;
    virtual void on_connected() = 0;
  };

  TransparentProxy(SocketFd socket_fd, IPAddress ip_address, string username, string password,
                   unique_ptr<Callback> callback, ActorShared<> parent);

 protected:
  BufferedFd<SocketFd> fd_;
  IPAddress ip_address_;
  string username_;
  string password_;
  unique_ptr<Callback> callback_;
  ActorShared<> parent_;

  void on_error(Status status);
  void tear_down() override;
  void start_up() override;
  void hangup() override;

  void loop() override;
  void timeout_expired() override;

  virtual Status loop_impl() = 0;
};

}  // namespace td
