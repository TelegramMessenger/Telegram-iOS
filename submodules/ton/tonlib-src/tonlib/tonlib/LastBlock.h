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
#include "td/actor/actor.h"

#include "tonlib/ExtClient.h"

namespace tonlib {
struct LastBlockInfo {
  ton::BlockIdExt id;
  td::int64 utime{0};
};
class LastBlock : public td::actor::Actor {
 public:
  struct State {
    ton::ZeroStateIdExt zero_state_id;
    ton::BlockIdExt last_key_block_id;
    ton::BlockIdExt last_block_id;
    td::int64 utime{0};
  };

  class Callback {
   public:
    virtual ~Callback() {
    }
    virtual void on_state_changes(State state) = 0;
  };

  explicit LastBlock(ExtClientRef client, State state, td::unique_ptr<Callback> callback);
  void get_last_block(td::Promise<LastBlockInfo> promise);

 private:
  ExtClient client_;
  State state_;
  td::unique_ptr<Callback> callback_;

  std::vector<td::Promise<LastBlockInfo>> promises_;

  void do_get_last_block();
  void on_masterchain_info(td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_masterchainInfo>> r_info);
  void on_block_proof(ton::BlockIdExt from,
                      td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof>> r_block_proof);
  td::Result<bool> process_block_proof(
      ton::BlockIdExt from,
      td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof>> r_block_proof);

  void update_zero_state(ton::ZeroStateIdExt zero_state_id);

  void update_mc_last_block(ton::BlockIdExt mc_block_id);
  void update_mc_last_key_block(ton::BlockIdExt mc_key_block_id);
  void update_utime(td::int64 utime);
};
}  // namespace tonlib
