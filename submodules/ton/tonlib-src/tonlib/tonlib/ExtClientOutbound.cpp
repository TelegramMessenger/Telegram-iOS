
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
#include "ExtClientOutbound.h"
#include <map>
namespace tonlib {

class ExtClientOutboundImp : public ExtClientOutbound {
 public:
  ExtClientOutboundImp(td::unique_ptr<ExtClientOutbound::Callback> callback) : callback_(std::move(callback)) {
  }

  void check_ready(td::Promise<td::Unit> promise) override {
    promise.set_error(td::Status::Error("Not supported"));
  }

  void send_query(std::string name, td::BufferSlice data, td::Timestamp timeout,
                  td::Promise<td::BufferSlice> promise) override {
    auto query_id = next_query_id_++;
    queries_[query_id] = std::move(promise);
    callback_->request(query_id, data.as_slice().str());
  }

  void on_query_result(td::int64 id, td::Result<td::BufferSlice> r_data, td::Promise<td::Unit> promise) override {
    auto it = queries_.find(id);
    if (it == queries_.end()) {
      promise.set_error(td::Status::Error(400, "Unknown query id"));
    }
    it->second.set_result(std::move(r_data));
    queries_.erase(it);
    promise.set_value(td::Unit());
  }

 private:
  td::unique_ptr<ExtClientOutbound::Callback> callback_;
  td::int64 next_query_id_{1};
  std::map<td::int64, td::Promise<td::BufferSlice>> queries_;

  void tear_down() override {
    for (auto &it : queries_) {
      it.second.set_error(td::Status::Error(400, "Query cancelled"));
    }
    queries_.clear();
  }
};

td::actor::ActorOwn<ExtClientOutbound> ExtClientOutbound::create(td::unique_ptr<Callback> callback) {
  return td::actor::create_actor<ExtClientOutboundImp>("ExtClientOutbound", std::move(callback));
}
}  // namespace tonlib
