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
#include "ExtClientLazy.h"
#include "TonlibError.h"
namespace tonlib {

class ExtClientLazyImp : public ton::adnl::AdnlExtClient {
 public:
  ExtClientLazyImp(ton::adnl::AdnlNodeIdFull dst, td::IPAddress dst_addr,
                   td::unique_ptr<ExtClientLazy::Callback> callback)
      : dst_(std::move(dst)), dst_addr_(std::move(dst_addr)), callback_(std::move(callback)) {
  }

  void check_ready(td::Promise<td::Unit> promise) override {
    before_query();
    if (client_.empty()) {
      return promise.set_error(TonlibError::Cancelled());
    }
    send_closure(client_, &ton::adnl::AdnlExtClient::check_ready, std::move(promise));
  }

  void send_query(std::string name, td::BufferSlice data, td::Timestamp timeout,
                  td::Promise<td::BufferSlice> promise) override {
    before_query();
    if (client_.empty()) {
      return promise.set_error(TonlibError::Cancelled());
    }
    send_closure(client_, &ton::adnl::AdnlExtClient::send_query, std::move(name), std::move(data), timeout,
                 std::move(promise));
  }

  void before_query() {
    if (is_closing_) {
      return;
    }
    if (!client_.empty()) {
      alarm_timestamp() = td::Timestamp::in(MAX_NO_QUERIES_TIMEOUT);
      return;
    }
    class Callback : public ton::adnl::AdnlExtClient::Callback {
     public:
      explicit Callback(td::actor::ActorShared<> parent) : parent_(std::move(parent)) {
      }
      void on_ready() override {
      }
      void on_stop_ready() override {
      }

     private:
      td::actor::ActorShared<> parent_;
    };
    ref_cnt_++;
    client_ = ton::adnl::AdnlExtClient::create(dst_, dst_addr_, std::make_unique<Callback>(td::actor::actor_shared()));
  }

 private:
  ton::adnl::AdnlNodeIdFull dst_;
  td::IPAddress dst_addr_;
  td::actor::ActorOwn<ton::adnl::AdnlExtClient> client_;
  td::unique_ptr<ExtClientLazy::Callback> callback_;
  static constexpr double MAX_NO_QUERIES_TIMEOUT = 100;

  bool is_closing_{false};
  td::uint32 ref_cnt_{1};

  void alarm() override {
    client_.reset();
  }
  void hangup_shared() override {
    ref_cnt_--;
    try_stop();
  }
  void hangup() override {
    is_closing_ = true;
    ref_cnt_--;
    client_.reset();
    try_stop();
  }
  void try_stop() {
    if (is_closing_ && ref_cnt_ == 0) {
      stop();
    }
  }
};

td::actor::ActorOwn<ton::adnl::AdnlExtClient> ExtClientLazy::create(ton::adnl::AdnlNodeIdFull dst,
                                                                    td::IPAddress dst_addr,
                                                                    td::unique_ptr<Callback> callback) {
  return td::actor::create_actor<ExtClientLazyImp>("ExtClientLazy", dst, dst_addr, std::move(callback));
}
}  // namespace tonlib
