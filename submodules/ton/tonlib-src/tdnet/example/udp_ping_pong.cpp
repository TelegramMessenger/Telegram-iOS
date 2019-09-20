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

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "td/actor/actor.h"

#include "td/utils/OptionsParser.h"
#include "td/utils/Observer.h"
#include "td/utils/port/UdpSocketFd.h"

#include "td/net/UdpServer.h"

// PingPong
class PingPong : public td::actor::Actor {
 public:
  PingPong(int port, td::IPAddress dest, bool use_tcp) : port_(port), dest_(std::move(dest)), use_tcp_(use_tcp) {
  }

 private:
  int port_;
  td::actor::ActorOwn<td::UdpServer> udp_server_;
  td::IPAddress dest_;
  bool is_closing_{false};
  bool use_tcp_{false};

  void start_up() override {
    class Callback : public td::UdpServer::Callback {
     public:
      Callback(td::actor::ActorShared<PingPong> ping_pong) : ping_pong_(std::move(ping_pong)) {
      }

     private:
      td::actor::ActorShared<PingPong> ping_pong_;
      void on_udp_message(td::UdpMessage udp_message) override {
        send_closure(ping_pong_, &PingPong::on_udp_message, std::move(udp_message));
      }
    };

    if (use_tcp_) {
      udp_server_ = td::UdpServer::create_via_tcp(PSLICE() << "UdpServer(via tcp) " << td::tag("port", port_), port_,
                                                  std::make_unique<Callback>(actor_shared(this)))
                        .move_as_ok();
    } else {
      udp_server_ = td::UdpServer::create(PSLICE() << "UdpServer " << td::tag("port", port_), port_,
                                          std::make_unique<Callback>(actor_shared(this)))
                        .move_as_ok();
    }

    alarm_timestamp() = td::Timestamp::now();
  }

  void on_udp_message(td::UdpMessage message) {
    if (is_closing_) {
      return;
    }
    if (message.error.is_error()) {
      LOG(ERROR) << "Got error " << message.error << " from " << message.address;
      return;
    }

    auto data_slice = message.data.as_slice();
    LOG(INFO) << "Got query " << td::format::escaped(data_slice) << " from " << message.address;
    if (data_slice[5] == 'i') {
      send_closure(udp_server_, &td::UdpServer::send,
                   td::UdpMessage{message.address, td::BufferSlice("magkpongpong"), {}});
    }
  }

  int cnt_{0};
  void alarm() override {
    if (++cnt_ > 10) {
      return close();
    }
    alarm_timestamp() = td::Timestamp::in(1);
    LOG(INFO) << "Send ping";
    send_closure(udp_server_, &td::UdpServer::send, td::UdpMessage{dest_, td::BufferSlice("magkpingping"), {}});
  }

  void close() {
    is_closing_ = true;
    udp_server_.reset();
  }
  void hangup_shared() override {
    // udp_server_ was_closed
    stop();
  }
  void tear_down() override {
    td::actor::SchedulerContext::get()->stop();
  }
};

int main(int argc, char *argv[]) {
  td::OptionsParser options_parser;
  options_parser.set_description("Udp ping server/client (8083 <-> 8084) (based on td::actors2)");

  int from_port = 8083;
  int to_port = 8084;
  bool is_client = false;
  bool use_tcp = false;
  options_parser.add_option('c', "client", "Work as client (server by default)", [&]() {
    is_client = true;
    return td::Status::OK();
  });
  options_parser.add_option('t', "tcp", "Use tcp (udp by default)", [&]() {
    use_tcp = true;
    return td::Status::OK();
  });
  auto status = options_parser.run(argc, argv);
  if (status.is_error()) {
    LOG(ERROR) << status.error();
    LOG(INFO) << options_parser;
    return 1;
  }
  if (is_client) {
    std::swap(from_port, to_port);
  }
  td::IPAddress to_ip;
  to_ip.init_ipv4_port("127.0.0.1", to_port).ensure();

  // NB: Interface will be changed
  td::actor::Scheduler scheduler({2});
  LOG(INFO) << "Listen to " << from_port;
  scheduler.run_in_context([&] {
    td::actor::create_actor<PingPong>(td::actor::ActorOptions().with_name("TcpClient").with_poll(), from_port, to_ip,
                                      use_tcp)
        .release();
  });
  scheduler.run();
  return 0;
}
