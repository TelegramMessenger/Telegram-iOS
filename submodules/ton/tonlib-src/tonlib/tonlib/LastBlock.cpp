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
#include "tonlib/LastBlock.h"

#include "ton/lite-tl.hpp"

#include "lite-client/lite-client-common.h"

namespace tonlib {
LastBlock::LastBlock(ExtClientRef client, ton::ZeroStateIdExt zero_state_id, ton::BlockIdExt last_block_id,
                     td::actor::ActorShared<> parent) {
  zero_state_id_ = std::move(zero_state_id);
  mc_last_block_id_ = std::move(last_block_id);
  client_.set_client(client);
  parent_ = std::move(parent);
}

void LastBlock::get_last_block(td::Promise<ton::BlockIdExt> promise) {
  if (promises_.empty()) {
    do_get_last_block();
  }
  promises_.push_back(std::move(promise));
}

void LastBlock::do_get_last_block() {
  client_.send_query(ton::lite_api::liteServer_getMasterchainInfo(),
                     [this](auto r_info) { this->on_masterchain_info(std::move(r_info)); });
  return;
  //liteServer.getBlockProof mode:# known_block:tonNode.blockIdExt target_block:mode.0?tonNode.blockIdExt = liteServer.PartialBlockProof;
  client_.send_query(
      ton::lite_api::liteServer_getBlockProof(0, create_tl_lite_block_id(mc_last_block_id_), nullptr),
      [this, from = mc_last_block_id_](auto r_block_proof) { this->on_block_proof(from, std::move(r_block_proof)); });
}

td::Result<bool> LastBlock::process_block_proof(
    ton::BlockIdExt from,
    td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof>> r_block_proof) {
  TRY_RESULT(block_proof, std::move(r_block_proof));
  LOG(ERROR) << to_string(block_proof);
  TRY_RESULT(chain, liteclient::deserialize_proof_chain(std::move(block_proof)));
  if (chain->from != from) {
    return td::Status::Error(PSLICE() << "block proof chain starts from block " << chain->from.to_str()
                                      << ", not from requested block " << from.to_str());
  }
  TRY_STATUS(chain->validate());
  update_mc_last_block(chain->to);
  return chain->complete;
}

void LastBlock::on_block_proof(
    ton::BlockIdExt from,
    td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof>> r_block_proof) {
  auto r_is_ready = process_block_proof(from, std::move(r_block_proof));
  if (r_is_ready.is_error()) {
    LOG(WARNING) << "Failed liteServer_getBlockProof " << r_block_proof.error();
    return;
  }
  auto is_ready = r_is_ready.move_as_ok();
  if (is_ready) {
    for (auto& promise : promises_) {
      auto copy = mc_last_block_id_;
      promise.set_value(std::move(copy));
    }
    promises_.clear();
  } else {
    do_get_last_block();
  }
}

void LastBlock::on_masterchain_info(
    td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_masterchainInfo>> r_info) {
  if (r_info.is_ok()) {
    auto info = r_info.move_as_ok();
    update_zero_state(create_zero_state_id(info->init_));
    update_mc_last_block(create_block_id(info->last_));
  } else {
    LOG(WARNING) << "Failed liteServer_getMasterchainInfo " << r_info.error();
  }
  for (auto& promise : promises_) {
    auto copy = mc_last_block_id_;
    promise.set_value(std::move(copy));
  }
  promises_.clear();
}

void LastBlock::update_zero_state(ton::ZeroStateIdExt zero_state_id) {
  if (!zero_state_id.is_valid()) {
    LOG(ERROR) << "Ignore invalid zero state update";
    return;
  }

  if (!zero_state_id_.is_valid()) {
    LOG(INFO) << "Init zerostate: " << zero_state_id.to_str();
    zero_state_id_ = std::move(zero_state_id);
    return;
  }

  if (zero_state_id_ == zero_state_id_) {
    return;
  }

  LOG(FATAL) << "Masterchain zerostate mismatch: expected: " << zero_state_id_.to_str() << ", found "
             << zero_state_id.to_str();
  // TODO: all other updates will be inconsitent.
  // One will have to restart ton client
}

void LastBlock::update_mc_last_block(ton::BlockIdExt mc_block_id) {
  if (!mc_block_id.is_valid()) {
    LOG(ERROR) << "Ignore invalid masterchain block";
    return;
  }
  if (!mc_last_block_id_.is_valid() || mc_last_block_id_.id.seqno < mc_block_id.id.seqno) {
    mc_last_block_id_ = mc_block_id;
    LOG(INFO) << "Update masterchain block id: " << mc_last_block_id_.to_str();
  }
}
}  // namespace tonlib
