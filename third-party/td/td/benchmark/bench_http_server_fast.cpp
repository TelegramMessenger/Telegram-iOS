//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/HttpHeaderCreator.h"
#include "td/net/HttpQuery.h"
#include "td/net/HttpReader.h"
#include "td/net/TcpListener.h"

#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"

#include "td/utils/buffer.h"
#include "td/utils/BufferedFd.h"
#include "td/utils/logging.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

class HttpEchoConnection final : public td::Actor {
 public:
  explicit HttpEchoConnection(td::SocketFd fd) : fd_(std::move(fd)) {
  }

 private:
  td::BufferedFd<td::SocketFd> fd_;
  td::HttpReader reader_;
  td::HttpQuery query_;
  void start_up() final {
    td::Scheduler::subscribe(fd_.get_poll_info().extract_pollable_fd(this));
    reader_.init(&fd_.input_buffer(), 1024 * 1024, 0);
  }
  void tear_down() final {
    td::Scheduler::unsubscribe_before_close(fd_.get_poll_info().get_pollable_fd_ref());
    fd_.close();
  }

  void handle_query() {
    query_ = td::HttpQuery();
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
    fd_.output_buffer().append(res.ok());
  }

  void loop() final {
    sync_with_poll(fd_);
    auto status = [&] {
      TRY_STATUS(loop_read());
      TRY_STATUS(loop_write());
      return td::Status::OK();
    }();
    if (status.is_error() || can_close_local(fd_)) {
      stop();
    }
  }
  td::Status loop_read() {
    TRY_STATUS(fd_.flush_read());
    while (true) {
      TRY_RESULT(need, reader_.read_next(&query_));
      if (need == 0) {
        handle_query();
      } else {
        break;
      }
    }
    return td::Status::OK();
  }
  td::Status loop_write() {
    TRY_STATUS(fd_.flush_write());
    return td::Status::OK();
  }
};

const int N = 8;
class Server final : public td::TcpListener::Callback {
 public:
  void start_up() final {
    listener_ =
        td::create_actor<td::TcpListener>("Listener", 8082, td::ActorOwn<td::TcpListener::Callback>(actor_id(this)));
  }
  void accept(td::SocketFd fd) final {
    pos_++;
    auto scheduler_id = pos_ % (N != 0 ? N : 1) + (N != 0);
    td::create_actor_on_scheduler<HttpEchoConnection>("HttpEchoConnection", scheduler_id, std::move(fd)).release();
  }
  void hangup() final {
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
