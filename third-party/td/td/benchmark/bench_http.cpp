//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/HttpOutboundConnection.h"
#include "td/net/HttpQuery.h"
#include "td/net/SslStream.h"

#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"

#include "td/utils/buffer.h"
#include "td/utils/BufferedFd.h"
#include "td/utils/logging.h"
#include "td/utils/port/IPAddress.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Status.h"

#include <atomic>
#include <limits>

std::atomic<int> counter;

class HttpClient final : public td::HttpOutboundConnection::Callback {
  void start_up() final {
    td::IPAddress addr;
    addr.init_ipv4_port("127.0.0.1", 8082).ensure();
    auto fd = td::SocketFd::open(addr);
    LOG_CHECK(fd.is_ok()) << fd.error();
    connection_ = td::create_actor<td::HttpOutboundConnection>(
        "Connect", td::BufferedFd<td::SocketFd>(fd.move_as_ok()), td::SslStream{}, std::numeric_limits<size_t>::max(),
        0, 0, td::ActorOwn<td::HttpOutboundConnection::Callback>(actor_id(this)));
    yield();
    cnt_ = 100000;
    counter++;
  }

  void tear_down() final {
    if (--counter == 0) {
      td::Scheduler::instance()->finish();
    }
  }

  void loop() final {
    if (cnt_-- < 0) {
      return stop();
    }
    send_closure(connection_, &td::HttpOutboundConnection::write_next, td::BufferSlice("GET / HTTP/1.1\r\n\r\n"));
    send_closure(connection_, &td::HttpOutboundConnection::write_ok);
    LOG(INFO) << "SEND";
  }

  void handle(td::unique_ptr<td::HttpQuery> result) final {
    loop();
  }

  void on_connection_error(td::Status error) final {
    LOG(ERROR) << "ERROR: " << error;
  }

  td::ActorOwn<td::HttpOutboundConnection> connection_;
  int cnt_ = 0;
};

int main() {
  SET_VERBOSITY_LEVEL(VERBOSITY_NAME(ERROR));
  auto scheduler = td::make_unique<td::ConcurrentScheduler>(0, 0);
  scheduler->create_actor_unsafe<HttpClient>(0, "Client1").release();
  scheduler->create_actor_unsafe<HttpClient>(0, "Client2").release();
  scheduler->start();
  while (scheduler->run_main(10)) {
    // empty
  }
  scheduler->finish();
}
