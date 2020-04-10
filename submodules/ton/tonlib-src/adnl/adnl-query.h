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

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "td/actor/actor.h"
#include "common/bitstring.h"
#include "common/errorcode.h"
#include "td/utils/buffer.h"

#include <functional>

namespace ton {

namespace adnl {

class AdnlPeerPair;

using AdnlQueryId = td::Bits256;

class AdnlQuery : public td::actor::Actor {
 public:
  static td::actor::ActorId<AdnlQuery> create(td::Promise<td::BufferSlice> promise,
                                              std::function<void(AdnlQueryId)> destroy, std::string name,
                                              td::Timestamp timeout, AdnlQueryId id) {
    return td::actor::create_actor<AdnlQuery>("query", name, std::move(promise), std::move(destroy), timeout, id)
        .release();
  }
  static AdnlQueryId random_query_id();
  AdnlQuery(std::string name, td::Promise<td::BufferSlice> promise, std::function<void(AdnlQueryId)> destroy,
            td::Timestamp timeout, AdnlQueryId id)
      : name_(std::move(name)), timeout_(timeout), promise_(std::move(promise)), destroy_(std::move(destroy)), id_(id) {
  }
  void alarm() override;
  void result(td::BufferSlice data);
  void start_up() override {
    alarm_timestamp() = timeout_;
  }
  void tear_down() override {
    destroy_(id_);
    if (promise_) {
      promise_.set_error(td::Status::Error(ErrorCode::cancelled, "Cancelled"));
    }
  }

 private:
  std::string name_;
  td::Timestamp timeout_;
  td::Promise<td::BufferSlice> promise_;
  std::function<void(AdnlQueryId)> destroy_;
  AdnlQueryId id_;
};

}  // namespace adnl

}  // namespace ton
