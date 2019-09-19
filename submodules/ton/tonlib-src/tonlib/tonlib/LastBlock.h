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
class LastBlock : public td::actor::Actor {
 public:
  explicit LastBlock(ExtClientRef client, ton::ZeroStateIdExt zero_state_id, ton::BlockIdExt last_block_id,
                     td::actor::ActorShared<> parent);

  void get_last_block(td::Promise<ton::BlockIdExt> promise);

 private:
  ExtClient client_;
  ton::ZeroStateIdExt zero_state_id_;
  ton::BlockIdExt mc_last_block_id_;

  std::vector<td::Promise<ton::BlockIdExt>> promises_;

  td::actor::ActorShared<> parent_;

  void do_get_last_block();
  void on_masterchain_info(td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_masterchainInfo>> r_info);
  void on_block_proof(ton::BlockIdExt from,
                      td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof>> r_block_proof);
  td::Result<bool> process_block_proof(
      ton::BlockIdExt from,
      td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof>> r_block_proof);

  void update_zero_state(ton::ZeroStateIdExt zero_state_id);

  void update_mc_last_block(ton::BlockIdExt mc_block_id);
};
}  // namespace tonlib
