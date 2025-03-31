//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/HttpInboundConnection.h"

#include "td/net/SslStream.h"

#include "td/utils/common.h"

namespace td {

HttpInboundConnection::HttpInboundConnection(BufferedFd<SocketFd> fd, size_t max_post_size, size_t max_files,
                                             int32 idle_timeout, ActorShared<Callback> callback,
                                             int32 slow_scheduler_id)
    : HttpConnectionBase(State::Read, std::move(fd), SslStream(), max_post_size, max_files, idle_timeout,
                         slow_scheduler_id)
    , callback_(std::move(callback)) {
}

void HttpInboundConnection::on_query(unique_ptr<HttpQuery> query) {
  CHECK(!callback_.empty());
  send_closure(callback_, &Callback::handle, std::move(query), ActorOwn<HttpInboundConnection>(actor_id(this)));
}

void HttpInboundConnection::on_error(Status error) {
  // nothing to do
}

}  // namespace td
