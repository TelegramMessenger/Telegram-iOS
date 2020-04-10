/* 
    This file is part of TON Blockchain source code.

    TON Blockchain is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    TON Blockchain is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with TON Blockchain.  If not, see <http://www.gnu.org/licenses/>.

    In addition, as a special exception, the copyright holders give permission 
    to link the code of portions of this program with the OpenSSL library. 
    You must obey the GNU General Public License in all respects for all 
    of the code used other than OpenSSL. If you modify file(s) with this 
    exception, you may extend this exception to your version of the file(s), 
    but you are not obligated to do so. If you do not wish to do so, delete this 
    exception statement from your version. If you delete this exception statement 
    from all source files in the program, then also delete it here.

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "td/actor/actor.h"

#include "td/utils/BufferedFd.h"
#include "td/utils/OptionsParser.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/port/ServerSocketFd.h"
#include "td/utils/Observer.h"

#include "td/net/TcpListener.h"

class PingClient : public td::actor::Actor, td::ObserverBase {
 public:
  PingClient(td::SocketFd fd) : buffered_fd_(std::move(fd)) {
  }

 private:
  td::BufferedFd<td::SocketFd> buffered_fd_;
  td::actor::ActorId<PingClient> self_;
  void notify() override {
    // NB: Interface will be changed
    send_closure_later(self_, &PingClient::on_net);
  }
  void on_net() {
    loop();
  }

  void start_up() override {
    self_ = actor_id(this);
    LOG(INFO) << "Start";
    // Subscribe for socket updates
    // NB: Interface will be changed
    td::actor::SchedulerContext::get()->get_poll().subscribe(buffered_fd_.get_poll_info().extract_pollable_fd(this),
                                                             td::PollFlags::ReadWrite());

    alarm_timestamp() = td::Timestamp::now();
  }

  void tear_down() override {
    LOG(INFO) << "Close";
    // unsubscribe from socket updates
    // nb: interface will be changed
    td::actor::SchedulerContext::get()->get_poll().unsubscribe(buffered_fd_.get_poll_info().get_pollable_fd_ref());
  }

  void loop() override {
    auto status = [&] {
      TRY_STATUS(buffered_fd_.flush_read());
      auto &input = buffered_fd_.input_buffer();
      while (input.size() >= 12) {
        auto query = input.cut_head(12).move_as_buffer_slice();
        LOG(INFO) << "Got query " << td::format::escaped(query.as_slice());
        if (query[5] == 'i') {
          LOG(INFO) << "Send ping";
          buffered_fd_.output_buffer().append("magkpongpong");
        } else {
          LOG(INFO) << "Got pong";
        }
      }

      TRY_STATUS(buffered_fd_.flush_write());
      if (td::can_close(buffered_fd_)) {
        stop();
      }
      return td::Status::OK();
    }();
    if (status.is_error()) {
      LOG(ERROR) << "Client got error " << status;
      stop();
    }
  }

  void alarm() override {
    alarm_timestamp() = td::Timestamp::in(5);
    LOG(INFO) << "Send ping";
    buffered_fd_.output_buffer().append("magkpingping");
    loop();
  }
};

int main(int argc, char *argv[]) {
  td::OptionsParser options_parser;
  options_parser.set_description("Tcp ping server/client (based on td::actors2)");

  int port = 8081;
  bool is_client = false;
  options_parser.add_option('p', "port", "listen/connect to tcp port (8081 by default)", [&](td::Slice arg) {
    port = td::to_integer<int>(arg);
    return td::Status::OK();
  });
  options_parser.add_option('c', "client", "Work as client (server by default)", [&]() {
    is_client = true;
    return td::Status::OK();
  });
  auto status = options_parser.run(argc, argv);
  if (status.is_error()) {
    LOG(ERROR) << status.error();
    LOG(INFO) << options_parser;
    return 1;
  }

  // NB: Interface will be changed
  td::actor::Scheduler scheduler({2});
  scheduler.run_in_context([&] {
    if (is_client) {
      td::IPAddress ip_address;
      ip_address.init_ipv4_port("127.0.0.1", port).ensure();
      td::actor::create_actor<PingClient>(td::actor::ActorOptions().with_name("TcpClient").with_poll(),
                                          td::SocketFd::open(ip_address).move_as_ok())
          .release();
    } else {
      class Callback : public td::TcpListener::Callback {
       public:
        void accept(td::SocketFd fd) override {
          td::actor::create_actor<PingClient>(td::actor::ActorOptions().with_name("TcpClient").with_poll(),
                                              std::move(fd))
              .release();
        }
      };
      td::actor::create_actor<td::TcpListener>(td::actor::ActorOptions().with_name("TcpServer").with_poll(), port,
                                               std::make_unique<Callback>())
          .release();
    }
  });
  scheduler.run();
  return 0;
}
