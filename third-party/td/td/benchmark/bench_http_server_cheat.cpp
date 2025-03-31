//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/HttpHeaderCreator.h"
#include "td/net/TcpListener.h"

#include "td/actor/actor.h"
#include "td/actor/ConcurrentScheduler.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <array>

static int cnt = 0;

class HelloWorld final : public td::Actor {
 public:
  explicit HelloWorld(td::SocketFd socket_fd) : socket_fd_(std::move(socket_fd)) {
  }

 private:
  td::SocketFd socket_fd_;

  std::array<char, 1024> read_buf;
  size_t read_new_lines{0};

  td::string hello_;
  td::string write_buf_;
  size_t write_pos_{0};

  void start_up() final {
    td::Scheduler::subscribe(socket_fd_.get_poll_info().extract_pollable_fd(this));
    td::HttpHeaderCreator hc;
    td::Slice content = "hello world";
    //auto content = td::BufferSlice("hello world");
    hc.init_ok();
    hc.set_keep_alive();
    hc.set_content_size(content.size());
    hc.add_header("Server", "TDLib/test");
    hc.add_header("Date", "Thu Dec 14 01:41:50 2017");
    hc.add_header("Content-Type:", "text/html");
    hello_ = hc.finish(content).ok().str();
  }

  void loop() final {
    auto status = do_loop();
    if (status.is_error()) {
      td::Scheduler::unsubscribe(socket_fd_.get_poll_info().get_pollable_fd_ref());
      stop();
      LOG(ERROR) << "CLOSE: " << status;
    }
  }
  td::Status do_loop() {
    sync_with_poll(socket_fd_);
    TRY_STATUS(read_loop());
    TRY_STATUS(write_loop());
    if (can_close_local(socket_fd_)) {
      return td::Status::Error("CLOSE");
    }
    return td::Status::OK();
  }
  td::Status write_loop() {
    while (can_write_local(socket_fd_) && write_pos_ < write_buf_.size()) {
      TRY_RESULT(written, socket_fd_.write(td::Slice(write_buf_).substr(write_pos_)));
      write_pos_ += written;
      if (write_pos_ == write_buf_.size()) {
        write_pos_ = 0;
        write_buf_.clear();
      }
    }
    return td::Status::OK();
  }
  td::Status read_loop() {
    while (can_read_local(socket_fd_)) {
      TRY_RESULT(read_size, socket_fd_.read(td::MutableSlice(read_buf.data(), read_buf.size())));
      for (size_t i = 0; i < read_size; i++) {
        if (read_buf[i] == '\n') {
          read_new_lines++;
          if (read_new_lines == 2) {
            read_new_lines = 0;
            write_buf_.append(hello_);
          }
        }
      }
    }
    return td::Status::OK();
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
    td::create_actor_on_scheduler<HelloWorld>("HelloWorld", scheduler_id, std::move(fd)).release();
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
