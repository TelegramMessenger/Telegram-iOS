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
#pragma once
#include "adnl/adnl-ext-client.h"
#include "tl-utils/lite-utils.hpp"

#include "auto/tl/lite_api.h"

#include "ton/ton-types.h"

#include "td/actor/actor.h"
#include "td/utils/Container.h"

namespace tonlib {
class LastBlock;
struct LastBlockState;
struct ExtClientRef {
  td::actor::ActorId<ton::adnl::AdnlExtClient> andl_ext_client_;
  td::actor::ActorId<LastBlock> last_block_actor_;
};

class ExtClient {
 public:
  ExtClient() = default;
  ExtClient(const ExtClient&) = delete;
  ExtClient(ExtClient&&) = delete;
  ExtClient& operator=(const ExtClient&) = delete;
  ExtClient& operator=(ExtClient&&) = delete;

  void set_client(ExtClientRef client) {
    client_ = client;
  }
  ExtClientRef get_client() {
    return client_;
  }

  void with_last_block(td::Promise<LastBlockState> promise);

  template <class QueryT>
  void send_query(QueryT query, td::Promise<typename QueryT::ReturnType> promise) {
    auto raw_query = ton::serialize_tl_object(&query, true);
    LOG(ERROR) << "send query to liteserver: " << to_string(query);
    td::BufferSlice liteserver_query =
        ton::serialize_tl_object(ton::create_tl_object<ton::lite_api::liteServer_query>(std::move(raw_query)), true);

    send_raw_query(std::move(liteserver_query), [promise = std::move(promise)](td::Result<td::BufferSlice> R) mutable {
      promise.set_result([&]() -> td::Result<typename QueryT::ReturnType> {
        TRY_RESULT(data, std::move(R));
        auto r_error = ton::fetch_tl_object<ton::lite_api::liteServer_error>(data.clone(), true);
        if (r_error.is_ok()) {
          auto f = r_error.move_as_ok();
          return td::Status::Error(f->code_, f->message_);
        }
        return ton::fetch_result<QueryT>(std::move(data));
      }());
    });
  }

 private:
  ExtClientRef client_;
  td::Container<td::Promise<td::BufferSlice>> queries_;
  td::Container<td::Promise<LastBlockState>> last_block_queries_;

  void send_raw_query(td::BufferSlice query, td::Promise<td::BufferSlice> promise);
};
}  // namespace tonlib
