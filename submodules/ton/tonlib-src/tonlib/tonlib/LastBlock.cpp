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

td::StringBuilder& operator<<(td::StringBuilder& sb, const LastBlockState& state) {
  return sb << td::tag("last_block", state.last_block_id.to_str())
            << td::tag("last_key_block", state.last_key_block_id.to_str()) << td::tag("utime", state.utime);
}

LastBlock::LastBlock(ExtClientRef client, LastBlockState state, Config config, td::unique_ptr<Callback> callback)
    : state_(std::move(state)), config_(std::move(config)), callback_(std::move(callback)) {
  client_.set_client(client);
  if (!config_.init_block_id.is_valid()) {
    check_init_block_state_ = QueryState::Done;
  }
}

void LastBlock::get_last_block(td::Promise<LastBlockState> promise) {
  if (has_fatal_error()) {
    promise.set_error(fatal_error_.clone());
    return;
  }
  if (promises_.empty() && get_last_block_state_ == QueryState::Done) {
    get_last_block_state_ = QueryState::Empty;
  }
  promises_.push_back(std::move(promise));
  sync_loop();
}

void LastBlock::sync_loop() {
  if (promises_.empty()) {
    return;
  }

  update_zero_state(state_.zero_state_id);
  update_zero_state(ton::ZeroStateIdExt(config_.zero_state_id.id.workchain, config_.zero_state_id.root_hash,
                                        config_.zero_state_id.file_hash));

  if (get_mc_info_state_ == QueryState::Empty) {
    get_mc_info_state_ = QueryState::Active;
    client_.send_query(ton::lite_api::liteServer_getMasterchainInfo(),
                       [this](auto r_info) { this->on_masterchain_info(std::move(r_info)); });
  }

  if (get_last_block_state_ == QueryState::Empty) {
    get_last_block_state_ = QueryState::Active;
    total_sync_ = td::Timer();
    validate_ = td::Timer(true);
    queries_ = 0;
    LOG(INFO) << "Begin last block synchronization " << state_;
    do_get_last_block();
  }

  if (check_init_block_state_ == QueryState::Empty) {
    if (state_.last_block_id.id.seqno >= config_.init_block_id.id.seqno) {
      check_init_block_state_ = QueryState::Active;
      // validate
      //total_sync_ = td::Timer();
      //validate_ = td::Timer(true);
      //queries_ = 0;
      LOG(INFO) << "Begin last block synchronization (check init_block)" << state_;
      do_check_init_block(state_.last_key_block_id);
    } else {
    }
  }

  if (get_mc_info_state_ == QueryState::Done && get_last_block_state_ == QueryState::Done &&
      check_init_block_state_ == QueryState::Done) {
    on_sync_ok();
  }
}

void LastBlock::do_get_last_block() {
  //liteServer.getBlockProof mode:# known_block:tonNode.blockIdExt target_block:mode.0?tonNode.blockIdExt = liteServer.PartialBlockProof;
  queries_++;
  client_.send_query(
      ton::lite_api::liteServer_getBlockProof(0, create_tl_lite_block_id(state_.last_key_block_id), nullptr),
      [this, from = state_.last_key_block_id](auto r_block_proof) {
        this->on_block_proof(from, std::move(r_block_proof));
      });
}

void LastBlock::do_check_init_block(ton::BlockIdExt from) {
  //liteServer.getBlockProof mode:# known_block:tonNode.blockIdExt target_block:mode.0?tonNode.blockIdExt = liteServer.PartialBlockProof;
  //queries_++;
  client_.send_query(ton::lite_api::liteServer_getBlockProof(1, create_tl_lite_block_id(from),
                                                             create_tl_lite_block_id(config_.init_block_id)),
                     [this, from = state_.last_key_block_id](auto r_block_proof) {
                       this->on_init_block_proof(from, std::move(r_block_proof));
                     });
}

td::Result<std::unique_ptr<block::BlockProofChain>> LastBlock::process_block_proof(
    ton::BlockIdExt from,
    td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof>> r_block_proof) {
  TRY_RESULT(block_proof, std::move(r_block_proof));
  LOG(DEBUG) << "Got proof FROM\n" << to_string(block_proof->from_) << "TO\n" << to_string(block_proof->to_);
  TRY_RESULT(chain, liteclient::deserialize_proof_chain(std::move(block_proof)));
  if (chain->from != from) {
    return td::Status::Error(PSLICE() << "block proof chain starts from block " << chain->from.to_str()
                                      << ", not from requested block " << from.to_str());
  }
  TRY_STATUS(chain->validate());
  bool is_changed = false;
  is_changed |= update_mc_last_block(chain->to);
  if (chain->has_key_block) {
    is_changed |= update_mc_last_key_block(chain->key_blkid);
  }
  if (chain->has_utime) {
    update_utime(chain->last_utime);
  }
  if (is_changed) {
    callback_->on_state_changed(state_);
  }
  return std::move(chain);
}

void LastBlock::on_block_proof(
    ton::BlockIdExt from,
    td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof>> r_block_proof) {
  validate_.resume();
  auto r_chain = process_block_proof(from, std::move(r_block_proof));
  validate_.pause();
  bool is_ready;
  if (r_chain.is_error()) {
    LOG(WARNING) << "Error during last block synchronization " << r_chain.error();
    if (config_.init_block_id.is_valid()) {
      if (state_.last_key_block_id.id.seqno < config_.init_block_id.id.seqno) {
        on_sync_error(td::Status::Error(PSLICE() << "Sync failed and we can't validate config.init_block: "
                                                 << r_chain.move_as_error()));
      }
    }
    is_ready = true;
  } else {
    is_ready = r_chain.ok()->complete;
  }
  if (is_ready) {
    LOG(INFO) << "End last block synchronization " << state_ << "\n"
              << "   net queries: " << queries_ << "\n"
              << "   total: " << total_sync_ << " validation: " << validate_;
    get_last_block_state_ = QueryState::Done;
    sync_loop();
  } else {
    do_get_last_block();
  }
}

void LastBlock::on_init_block_proof(
    ton::BlockIdExt from,
    td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof>> r_block_proof) {
  validate_.resume();
  auto r_chain = process_block_proof(from, std::move(r_block_proof));
  validate_.pause();
  if (r_chain.is_error()) {
    check_init_block_state_ = QueryState::Empty;
    on_sync_error(
        td::Status::Error(PSLICE() << "Error during last block synchronization (check init_block)" << r_chain.error()));
    return;
  }
  auto chain = r_chain.move_as_ok();
  if (chain->complete) {
    LOG(INFO) << "End last block synchronization " << state_ << "\n"
              << "   net queries: " << queries_ << "\n"
              << "   total: " << total_sync_ << " validation: " << validate_;
    get_last_block_state_ = QueryState::Done;
    sync_loop();
  } else {
    do_check_init_block(chain->to);
  }
}

void LastBlock::on_masterchain_info(
    td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_masterchainInfo>> r_info) {
  if (r_info.is_ok()) {
    auto info = r_info.move_as_ok();
    update_zero_state(create_zero_state_id(info->init_));
    update_mc_last_block(create_block_id(info->last_));
    get_mc_info_state_ = QueryState::Done;
  } else {
    get_mc_info_state_ = QueryState::Empty;
    LOG(WARNING) << "Failed liteServer_getMasterchainInfo " << r_info.error();
    on_sync_error(r_info.move_as_error());
  }
  sync_loop();
}

void LastBlock::update_zero_state(ton::ZeroStateIdExt zero_state_id) {
  if (has_fatal_error()) {
    return;
  }
  if (!zero_state_id.is_valid()) {
    LOG(ERROR) << "Ignore invalid zero state update";
    return;
  }

  if (!state_.zero_state_id.is_valid()) {
    LOG(INFO) << "Init zerostate: " << zero_state_id.to_str();
    state_.zero_state_id = std::move(zero_state_id);
    return;
  }

  if (state_.zero_state_id == zero_state_id) {
    return;
  }

  on_fatal_error(td::Status::Error(PSLICE() << "Masterchain zerostate mismatch: expected: "
                                            << state_.zero_state_id.to_str() << ", found " << zero_state_id.to_str()));
}

bool LastBlock::update_mc_last_block(ton::BlockIdExt mc_block_id) {
  if (has_fatal_error()) {
    return false;
  }
  if (!mc_block_id.is_valid()) {
    LOG(ERROR) << "Ignore invalid masterchain block";
    return false;
  }
  if (!state_.last_block_id.is_valid() || state_.last_block_id.id.seqno < mc_block_id.id.seqno) {
    state_.last_block_id = mc_block_id;
    LOG(INFO) << "Update masterchain block id: " << state_.last_block_id.to_str();
    return true;
  }
  return false;
}

bool LastBlock::update_mc_last_key_block(ton::BlockIdExt mc_key_block_id) {
  if (has_fatal_error()) {
    return false;
  }
  if (!mc_key_block_id.is_valid()) {
    LOG(ERROR) << "Ignore invalid masterchain block";
    return false;
  }
  if (!state_.last_key_block_id.is_valid() || state_.last_key_block_id.id.seqno < mc_key_block_id.id.seqno) {
    state_.last_key_block_id = mc_key_block_id;
    LOG(INFO) << "Update masterchain key block id: " << state_.last_key_block_id.to_str();
    return true;
  }
  return false;
}

void LastBlock::update_utime(td::int64 utime) {
  if (state_.utime < utime) {
    state_.utime = utime;
  }
}

void LastBlock::on_sync_ok() {
  for (auto& promise : promises_) {
    auto state = state_;
    promise.set_value(std::move(state));
  }
  promises_.clear();
}
void LastBlock::on_sync_error(td::Status status) {
  for (auto& promise : promises_) {
    promise.set_error(status.clone());
  }
  promises_.clear();
}
void LastBlock::on_fatal_error(td::Status status) {
  fatal_error_ = std::move(status);
  on_sync_error(fatal_error_.clone());
}

bool LastBlock::has_fatal_error() const {
  return fatal_error_.is_error();
}
}  // namespace tonlib
