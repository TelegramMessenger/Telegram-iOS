/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#include "td/net/UdpServer.h"
#include "td/net/FdListener.h"
#include "td/net/TcpListener.h"

#include "td/utils/BufferedFd.h"

#include <map>

namespace td {
namespace {
int VERBOSITY_NAME(udp_server) = VERBOSITY_NAME(DEBUG) + 10;
}
namespace detail {
class UdpServerImpl : public UdpServer {
 public:
  void send(td::UdpMessage &&message) override;
  static td::actor::ActorOwn<UdpServerImpl> create(td::Slice name, td::UdpSocketFd fd,
                                                   std::unique_ptr<Callback> callback);

  UdpServerImpl(td::UdpSocketFd fd, std::unique_ptr<Callback> callback);

 private:
  td::actor::ActorOwn<> fd_listener_;
  std::unique_ptr<Callback> callback_;
  td::BufferedUdp fd_;
  bool is_closing_{false};

  void start_up() override;
  void on_fd_updated();

  void loop() override;

  void hangup() override;
  void hangup_shared() override;
};

void UdpServerImpl::send(td::UdpMessage &&message) {
  fd_.send(std::move(message));
  loop();  // TODO: some yield logic
}

td::actor::ActorOwn<UdpServerImpl> UdpServerImpl::create(td::Slice name, td::UdpSocketFd fd,
                                                         std::unique_ptr<Callback> callback) {
  return td::actor::create_actor<UdpServerImpl>(
      actor::ActorOptions().with_name(name).with_poll(!td::Poll::is_edge_triggered()), std::move(fd),
      std::move(callback));
}

UdpServerImpl::UdpServerImpl(td::UdpSocketFd fd, std::unique_ptr<Callback> callback)
    : callback_(std::move(callback)), fd_(std::move(fd)) {
}

void UdpServerImpl::start_up() {
  //CHECK(td::actor::SchedulerContext::get()->has_poll() == false);
  class Observer : public td::ObserverBase, public Destructor {
   public:
    Observer(td::actor::ActorShared<UdpServerImpl> udp_server) : udp_server_(std::move(udp_server)) {
    }
    void notify() override {
      VLOG(udp_server) << "on_fd_updated";
      td::actor::send_signals_later(udp_server_, td::actor::ActorSignals::wakeup());
    }

   private:
    td::actor::ActorShared<UdpServerImpl> udp_server_;
  };

  auto observer = std::make_unique<Observer>(actor_shared(this));
  auto pollable_fd = fd_.get_poll_info().extract_pollable_fd(observer.get());
  fd_listener_ = td::actor::create_actor<FdListener>(actor::ActorOptions().with_name("FdListener").with_poll(),
                                                     std::move(pollable_fd), std::move(observer));
}

void UdpServerImpl::on_fd_updated() {
  loop();
}

void UdpServerImpl::loop() {
  if (is_closing_) {
    return;
  }
  //CHECK(td::actor::SchedulerContext::get()->has_poll() == false);
  fd_.get_poll_info().get_flags();
  VLOG(udp_server) << "loop " << td::tag("can read", can_read(fd_)) << " " << td::tag("can write", can_write(fd_));
  Status status;
  status = [&] {
    while (true) {
      TRY_RESULT(o_message, fd_.receive());
      if (!o_message) {
        return Status::OK();
      }
      callback_->on_udp_message(std::move(*o_message));
    }
    return Status::OK();
  }();
  if (status.is_ok()) {
    status = fd_.flush_send();
  }

  if (status.is_error()) {
    VLOG(udp_server) << "Got " << status << " sleep for 1 second";
    alarm_timestamp() = Timestamp::in(1);
  }
}

void UdpServerImpl::hangup() {
  is_closing_ = true;
  // wait till fd_listener_ is closed and fd is unsubscribed
  fd_listener_.reset();
}
void UdpServerImpl::hangup_shared() {
  stop();
}

class TcpClient : public td::actor::Actor, td::ObserverBase {
 public:
  class Callback {
   public:
    virtual ~Callback() = default;
    virtual void on_message(BufferSlice data) = 0;
    virtual void on_closed(actor::ActorId<>) = 0;
  };
  TcpClient(td::SocketFd fd, std::unique_ptr<Callback> callback)
      : buffered_fd_(std::move(fd)), callback_(std::move(callback)) {
  }

  void send(BufferSlice data) {
    uint32 data_size = narrow_cast<uint32>(data.size());

    buffered_fd_.output_buffer().append(Slice(reinterpret_cast<char *>(&data_size), sizeof(data_size)));
    buffered_fd_.output_buffer().append(std::move(data));
    loop();
  }

 private:
  td::BufferedFd<td::SocketFd> buffered_fd_;
  std::unique_ptr<Callback> callback_;
  td::actor::ActorId<TcpClient> self_;

  void notify() override {
    // NB: Interface will be changed
    td::actor::send_closure_later(self_, &TcpClient::on_net);
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
                                                             PollFlags::ReadWrite());
    alarm_timestamp() = Timestamp::in(10);
    notify();
  }

  void tear_down() override {
    LOG(INFO) << "Close";
    // unsubscribe from socket updates
    // nb: interface will be changed
    td::actor::SchedulerContext::get()->get_poll().unsubscribe(buffered_fd_.get_poll_info().get_pollable_fd_ref());
    callback_->on_closed(actor_id(this));
  }

  void loop() override {
    auto status = [&] {
      TRY_STATUS(buffered_fd_.flush_read());
      auto &input = buffered_fd_.input_buffer();
      while (true) {
        constexpr size_t header_size = 4;
        if (input.size() < header_size) {
          break;
        }
        auto it = input.clone();
        uint32 data_size;
        it.advance(header_size, MutableSlice(reinterpret_cast<uint8 *>(&data_size), sizeof(data_size)));
        if (data_size > (1 << 26)) {
          return Status::Error("Too big packet");
        }
        if (it.size() < data_size) {
          break;
        }
        auto data = it.cut_head(data_size).move_as_buffer_slice();
        alarm_timestamp() = Timestamp::in(10);
        callback_->on_message(std::move(data));
        input = std::move(it);
      }

      TRY_STATUS(buffered_fd_.flush_write());
      if (td::can_close(buffered_fd_)) {
        stop();
      }
      return td::Status::OK();
    }();
    if (status.is_error()) {
      LOG(INFO) << "Client got error " << status;
      stop();
    }
  }
  void alarm() override {
    LOG(INFO) << "Close because of timeout";
    stop();
  }
};

struct Target {
  IPAddress ip_address;
  actor::ActorOwn<TcpClient> inbound;
  actor::ActorOwn<TcpClient> outbound;
};

class TargetSet {
 public:
  using Id = size_t;
  Id register_target(IPAddress address) {
    auto it_ok = ip_to_id_.insert(std::make_pair(address, 0));
    if (it_ok.second) {
      id_to_target_.push_back({});
      id_to_target_.back().ip_address = address;
      it_ok.first->second = id_to_target_.size();
    }
    return it_ok.first->second;
  }

  Target &get_target(Id id) {
    return id_to_target_.at(id - 1);
  }

 private:
  std::map<IPAddress, size_t> ip_to_id_;
  std::vector<Target> id_to_target_;
};
class UdpServerViaTcp : public UdpServer {
 public:
  UdpServerViaTcp(int32 port, std::unique_ptr<Callback> callback) : port_(port), callback_(std::move(callback)) {
  }

 private:
  int32 port_;
  std::unique_ptr<Callback> callback_;
  actor::ActorOwn<TcpInfiniteListener> tcp_listener_;
  TargetSet target_set_;
  int refcnt_{0};
  bool close_flag_{false};

  void start_up() override {
    //TcpInfiniteListener
    class TcpListenerCallback : public TcpListener::Callback {
     public:
      TcpListenerCallback(actor::ActorShared<UdpServerViaTcp> parent) : parent_(std::move(parent)) {
      }
      void accept(SocketFd fd) override {
        actor::send_closure(parent_, &UdpServerViaTcp::accept, std::move(fd));
      }

     private:
      actor::ActorShared<UdpServerViaTcp> parent_;
    };
    refcnt_++;
    tcp_listener_ = actor::create_actor<TcpInfiniteListener>(PSLICE() << "TcpInfiniteListener" << port_, port_,
                                                             std::make_unique<TcpListenerCallback>(actor_shared(this)));
  }

  void send(UdpMessage &&message) override {
    if (close_flag_) {
      return;
    }
    auto target_id = target_set_.register_target(message.address);
    auto &target = target_set_.get_target(target_id);
    if (target.inbound.empty() && target.outbound.empty()) {
      auto r_fd = SocketFd::open(target.ip_address);
      if (r_fd.is_error()) {
        LOG(INFO) << r_fd.error();
        return;
      }
      auto fd = r_fd.move_as_ok();
      do_accept(std::move(fd), message.address, false);
    }
    if (!target.inbound.empty()) {
      send_closure_later(target.inbound, &TcpClient::send, std::move(message.data));
    } else if (!target.outbound.empty()) {
      send_closure_later(target.outbound, &TcpClient::send, std::move(message.data));
    }
  }

  void on_message(BufferSlice data) {
    if (close_flag_) {
      return;
    }
    auto token = get_link_token();
    auto &target = target_set_.get_target(narrow_cast<TargetSet::Id>(token));
    UdpMessage message;
    message.address = target.ip_address;
    message.data = std::move(data);
    callback_->on_udp_message(std::move(message));
  }
  void on_closed(actor::ActorId<> id) {
    if (close_flag_) {
      return;
    }
    auto token = get_link_token();
    auto &target = target_set_.get_target(narrow_cast<TargetSet::Id>(token));
    if (target.inbound.get() == id) {
      target.inbound.reset();
    }
    if (target.outbound.get() == id) {
      target.outbound.reset();
    }
  }

  void accept(SocketFd fd) {
    if (close_flag_) {
      return;
    }
    IPAddress ip_address;
    auto status = ip_address.init_peer_address(fd);
    if (status.is_error()) {
      LOG(INFO) << status;
      return;
    }
    do_accept(std::move(fd), ip_address, true);
  }
  void do_accept(SocketFd fd, IPAddress ip_address, bool is_inbound) {
    class TcpClientCallback : public TcpClient::Callback {
     public:
      TcpClientCallback(actor::ActorShared<UdpServerViaTcp> parent) : parent_(std::move(parent)) {
      }
      void on_message(BufferSlice data) override {
        send_closure(parent_, &UdpServerViaTcp::on_message, std::move(data));
      }
      void on_closed(actor::ActorId<> id) override {
        send_closure(parent_, &UdpServerViaTcp::on_closed, std::move(id));
      }

     private:
      actor::ActorShared<UdpServerViaTcp> parent_;
    };

    auto target_id = target_set_.register_target(ip_address);
    auto &target = target_set_.get_target(target_id);
    refcnt_++;
    auto actor = actor::create_actor<TcpClient>(actor::ActorOptions().with_name("TcpClient").with_poll(), std::move(fd),
                                                std::make_unique<TcpClientCallback>(actor_shared(this, target_id)));
    if (is_inbound) {
      target.inbound = std::move(actor);
    } else {
      target.outbound = std::move(actor);
    }
  }

  void hangup() override {
    close_flag_ = true;
    target_set_ = {};
    tcp_listener_ = {};
  }

  void hangup_shared() override {
    refcnt_--;
    if (refcnt_ == 0) {
      stop();
    }
  }

  void loop() override {
  }
};

}  // namespace detail

Result<actor::ActorOwn<UdpServer>> UdpServer::create(td::Slice name, int32 port, std::unique_ptr<Callback> callback) {
  td::IPAddress from_ip;
  TRY_STATUS(from_ip.init_ipv4_port("0.0.0.0", port));
  TRY_RESULT(fd, UdpSocketFd::open(from_ip));
  fd.maximize_rcv_buffer().ensure();
  return detail::UdpServerImpl::create(name, std::move(fd), std::move(callback));
}
Result<actor::ActorOwn<UdpServer>> UdpServer::create_via_tcp(td::Slice name, int32 port,
                                                             std::unique_ptr<Callback> callback) {
  return actor::create_actor<detail::UdpServerViaTcp>(name, port, std::move(callback));
}

}  // namespace td
