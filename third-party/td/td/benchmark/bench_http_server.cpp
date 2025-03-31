//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/HttpHeaderCreator.h"
#include "td/net/HttpInboundConnection.h"
#include "td/net/HttpQuery.h"
#include "td/net/TcpListener.h"

#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"

#include "td/utils/buffer.h"
#include "td/utils/BufferedFd.h"
#include "td/utils/logging.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Slice.h"

static int cnt = 0;

class HelloWorld final : public td::HttpInboundConnection::Callback {
 public:
  void handle(td::unique_ptr<td::HttpQuery> query, td::ActorOwn<td::HttpInboundConnection> connection) final {
    // LOG(ERROR) << *query;
    td::HttpHeaderCreator hc;
    td::Slice content = "hello world";
    //auto content = td::BufferSlice("hello world");
    hc.init_ok();
    hc.set_keep_alive();
    hc.set_content_size(content.size());
    hc.add_header("Server", "TDLib/test");
    hc.add_header("Date", "Thu Dec 14 01:41:50 2017");
    hc.add_header("Content-Type:", "text/html");

    auto res = hc.finish(content);
    LOG_IF(FATAL, res.is_error()) << res.error();
    send_closure(connection, &td::HttpInboundConnection::write_next, td::BufferSlice(res.ok()));
    send_closure(connection.release(), &td::HttpInboundConnection::write_ok);
  }
  void hangup() final {
    LOG(ERROR) << "CLOSE " << cnt--;
    stop();
  }
};

const int N = 0;
class Server final : public td::TcpListener::Callback {
 public:
  void start_up() final {
    listener_ =
        td::create_actor<td::TcpListener>("Listener", 8082, td::ActorOwn<td::TcpListener::Callback>(actor_id(this)));
  }
  void accept(td::SocketFd fd) final {
    LOG(ERROR) << "ACCEPT " << cnt++;
    pos_++;
    auto scheduler_id = pos_ % (N != 0 ? N : 1) + (N != 0);
    td::create_actor_on_scheduler<td::HttpInboundConnection>(
        "HttpInboundConnection", scheduler_id, td::BufferedFd<td::SocketFd>(std::move(fd)), 1024 * 1024, 0, 0,
        td::create_actor_on_scheduler<HelloWorld>("HelloWorld", scheduler_id))
        .release();
  }
  void hangup() final {
    // may be it should be default?..
    LOG(ERROR) << "Hanging up..";
    stop();
  }

 private:
  td::ActorOwn<td::TcpListener> listener_;
  int pos_{0};
};

int main() {
  SET_VERBOSITY_LEVEL(VERBOSITY_NAME(ERROR));
  auto scheduler = td::make_unique<td::ConcurrentScheduler>(N, 0);
  scheduler->create_actor_unsafe<Server>(0, "Server").release();
  scheduler->start();
  while (scheduler->run_main(10)) {
    // empty
  }
  scheduler->finish();
}
