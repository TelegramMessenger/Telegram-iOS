//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/net/HttpConnectionBase.h"
#include "td/net/HttpQuery.h"

#include "td/actor/actor.h"

#include "td/utils/BufferedFd.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Status.h"

namespace td {

class HttpInboundConnection final : public detail::HttpConnectionBase {
 public:
  class Callback : public Actor {
   public:
    virtual void handle(unique_ptr<HttpQuery> query, ActorOwn<HttpInboundConnection> connection) = 0;
  };
  // Inherited interface
  // void write_next(BufferSlice buffer);
  // void write_ok();
  // void write_error(Status error);

  HttpInboundConnection(BufferedFd<SocketFd> fd, size_t max_post_size, size_t max_files, int32 idle_timeout,
                        ActorShared<Callback> callback, int32 slow_scheduler_id = -1);

 private:
  void on_query(unique_ptr<HttpQuery> query) final;
  void on_error(Status error) final;
  void hangup() final {
    callback_.release();
    stop();
  }
  ActorShared<Callback> callback_;
};

}  // namespace td
