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
#include "td/utils/Random.h"

#include "TonlibError.h"
#include "utils.h"

namespace tonlib {
class LastBlock;
class LastConfig;
struct LastBlockState;
struct LastConfigState;
struct ExtClientRef {
  td::actor::ActorId<ton::adnl::AdnlExtClient> andl_ext_client_;
  td::actor::ActorId<LastBlock> last_block_actor_;
  td::actor::ActorId<LastConfig> last_config_actor_;
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
  ~ExtClient();

  void with_last_block(td::Promise<LastBlockState> promise);
  void with_last_config(td::Promise<LastConfigState> promise);

  template <class QueryT>
  void send_query(QueryT query, td::Promise<typename QueryT::ReturnType> promise, td::int32 seq_no = -1) {
    auto raw_query = ton::serialize_tl_object(&query, true);
    td::uint32 tag = td::Random::fast_uint32();
    VLOG(lite_server) << "send query to liteserver: " << tag << " " << to_string(query);
    if (seq_no >= 0) {
      auto wait = ton::lite_api::liteServer_waitMasterchainSeqno(seq_no, 5000);
      VLOG(lite_server) << " with prefix " << to_string(wait);
      auto prefix = ton::serialize_tl_object(&wait, true);
      raw_query = td::BufferSlice(PSLICE() << prefix.as_slice() << raw_query.as_slice());
    }
    td::BufferSlice liteserver_query =
        ton::serialize_tl_object(ton::create_tl_object<ton::lite_api::liteServer_query>(std::move(raw_query)), true);

    send_raw_query(
        std::move(liteserver_query), [promise = std::move(promise), tag](td::Result<td::BufferSlice> R) mutable {
          auto res = [&]() -> td::Result<typename QueryT::ReturnType> {
            TRY_RESULT_PREFIX(data, std::move(R), TonlibError::LiteServerNetwork());
            auto r_error = ton::fetch_tl_object<ton::lite_api::liteServer_error>(data.clone(), true);
            if (r_error.is_ok()) {
              auto f = r_error.move_as_ok();
              return TonlibError::LiteServer(f->code_, f->message_);
            }
            return ton::fetch_result<QueryT>(std::move(data));
          }
          ();
          VLOG_IF(lite_server, res.is_ok())
              << "got result from liteserver: " << tag << " " << td::Slice(to_string(res.ok())).truncate(1 << 12);
          VLOG_IF(lite_server, res.is_error()) << "got error from liteserver: " << tag << " " << res.error();
          promise.set_result(std::move(res));
        });
  }

 private:
  ExtClientRef client_;
  td::Container<td::Promise<td::BufferSlice>> queries_;
  td::Container<td::Promise<LastBlockState>> last_block_queries_;
  td::Container<td::Promise<LastConfigState>> last_config_queries_;

  void send_raw_query(td::BufferSlice query, td::Promise<td::BufferSlice> promise);
};
}  // namespace tonlib
