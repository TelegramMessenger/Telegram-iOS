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
#include "tonlib/ExtClient.h"

#include "tonlib/LastBlock.h"
#include "tonlib/LastConfig.h"

namespace tonlib {
ExtClient::~ExtClient() {
  last_config_queries_.for_each([](auto id, auto &promise) { promise.set_error(TonlibError::Cancelled()); });
  last_block_queries_.for_each([](auto id, auto &promise) { promise.set_error(TonlibError::Cancelled()); });
  queries_.for_each([](auto id, auto &promise) { promise.set_error(TonlibError::Cancelled()); });
}
void ExtClient::with_last_config(td::Promise<LastConfigState> promise) {
  auto query_id = last_config_queries_.create(std::move(promise));
  td::Promise<LastConfigState> P = [query_id, self = this,
                                    actor_id = td::actor::actor_id()](td::Result<LastConfigState> result) {
    send_lambda(actor_id, [self, query_id, result = std::move(result)]() mutable {
      self->last_config_queries_.extract(query_id).set_result(std::move(result));
    });
  };
  if (client_.last_block_actor_.empty()) {
    return P.set_error(TonlibError::NoLiteServers());
  }
  td::actor::send_closure(client_.last_config_actor_, &LastConfig::get_last_config, std::move(P));
}
void ExtClient::with_last_block(td::Promise<LastBlockState> promise) {
  auto query_id = last_block_queries_.create(std::move(promise));
  td::Promise<LastBlockState> P = [query_id, self = this,
                                   actor_id = td::actor::actor_id()](td::Result<LastBlockState> result) {
    send_lambda(actor_id, [self, query_id, result = std::move(result)]() mutable {
      self->last_block_queries_.extract(query_id).set_result(std::move(result));
    });
  };
  if (client_.last_block_actor_.empty()) {
    return P.set_error(TonlibError::NoLiteServers());
  }
  td::actor::send_closure(client_.last_block_actor_, &LastBlock::get_last_block, std::move(P));
}

void ExtClient::send_raw_query(td::BufferSlice query, td::Promise<td::BufferSlice> promise) {
  auto query_id = queries_.create(std::move(promise));
  td::Promise<td::BufferSlice> P = [query_id, self = this,
                                    actor_id = td::actor::actor_id()](td::Result<td::BufferSlice> result) {
    send_lambda(actor_id, [self, query_id, result = std::move(result)]() mutable {
      self->queries_.extract(query_id).set_result(std::move(result));
    });
  };
  if (client_.andl_ext_client_.empty()) {
    return P.set_error(TonlibError::NoLiteServers());
  }
  td::actor::send_closure(client_.andl_ext_client_, &ton::adnl::AdnlExtClient::send_query, "query", std::move(query),
                          td::Timestamp::in(10.0), std::move(P));
}
}  // namespace tonlib
