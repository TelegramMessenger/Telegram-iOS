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

#include "tonlib/utils.h"

#include "ton/lite-tl.hpp"

#include "lite-client/lite-client-common.h"

namespace tonlib {

// init_state <-> last_key_block
// state.valitated_init_state
// last_key_block ->
//
td::StringBuilder& operator<<(td::StringBuilder& sb, const LastBlockState& state) {
  return sb << td::tag("last_block", state.last_block_id.to_str())
            << td::tag("last_key_block", state.last_key_block_id.to_str()) << td::tag("utime", state.utime)
            << td::tag("init_block", state.init_block_id.to_str());
}

LastBlock::LastBlock(ExtClientRef client, LastBlockState state, Config config, td::unique_ptr<Callback> callback)
    : state_(std::move(state)), config_(std::move(config)), callback_(std::move(callback)) {
  client_.set_client(client);
  state_.last_block_id = state_.last_key_block_id;

  VLOG(last_block) << "State: " << state_;
}

void LastBlock::get_last_block(td::Promise<LastBlockState> promise) {
  if (has_fatal_error()) {
    promise.set_error(fatal_error_.clone());
    return;
  }

  if (promises_.empty() && get_last_block_state_ == QueryState::Done) {
    VLOG(last_block) << "sync: start";
    VLOG(last_block) << "get_last_block: reset";
    get_last_block_state_ = QueryState::Empty;
  }

  promises_.push_back(std::move(promise));
  sync_loop();
}

void LastBlock::sync_loop() {
  if (promises_.empty()) {
    return;
  }

  update_zero_state(state_.zero_state_id, "cache");
  update_zero_state(ton::ZeroStateIdExt(config_.zero_state_id.id.workchain, config_.zero_state_id.root_hash,
                                        config_.zero_state_id.file_hash),
                    "config");

  if (get_mc_info_state_ == QueryState::Empty) {
    VLOG(last_block) << "get_masterchain_info: start";
    get_mc_info_state_ = QueryState::Active;
    client_.send_query(ton::lite_api::liteServer_getMasterchainInfo(),
                       [this](auto r_info) { this->on_masterchain_info(std::move(r_info)); });
  }

  if (check_init_block_state_ == QueryState::Empty) {
    if (!config_.init_block_id.is_valid()) {
      check_init_block_state_ = QueryState::Done;
      VLOG(last_block) << "check_init_block: skip - no init_block in config";
    } else if (config_.init_block_id == state_.init_block_id) {
      check_init_block_state_ = QueryState::Done;
      VLOG(last_block) << "check_init_block: skip - was checked before";
    } else {
      check_init_block_state_ = QueryState::Active;
      check_init_block_stats_.start();
      if (state_.last_key_block_id.id.seqno >= config_.init_block_id.id.seqno) {
        VLOG(last_block) << "check_init_block: start - init_block -> last_block";
        do_check_init_block(config_.init_block_id, state_.last_key_block_id);
      } else {
        VLOG(last_block) << "check_init_block: start - last_block -> init_block";
        do_check_init_block(state_.last_key_block_id, config_.init_block_id);
      }
    }
  }

  if (get_last_block_state_ == QueryState::Empty && check_init_block_state_ == QueryState::Done) {
    VLOG(last_block) << "get_last_block: start";
    get_last_block_stats_.start();
    get_last_block_state_ = QueryState::Active;
    do_get_last_block();
  }

  if (get_mc_info_state_ == QueryState::Done && get_last_block_state_ == QueryState::Done &&
      check_init_block_state_ == QueryState::Done) {
    on_sync_ok();
  }
}

void LastBlock::do_get_last_block() {
  //liteServer.getBlockProof mode:# known_block:tonNode.blockIdExt target_block:mode.0?tonNode.blockIdExt = liteServer.PartialBlockProof;
  VLOG(last_block) << "get_last_block: continue " << state_.last_key_block_id.to_str() << " -> ?";
  get_last_block_stats_.queries_++;
  client_.send_query(
      ton::lite_api::liteServer_getBlockProof(0, create_tl_lite_block_id(state_.last_key_block_id), nullptr),
      [this, from = state_.last_key_block_id](auto r_block_proof) {
        this->on_block_proof(from, std::move(r_block_proof));
      });
}

void LastBlock::do_check_init_block(ton::BlockIdExt from, ton::BlockIdExt to) {
  VLOG(last_block) << "check_init_block: continue " << from.to_str() << " -> " << to.to_str();
  //liteServer.getBlockProof mode:# known_block:tonNode.blockIdExt target_block:mode.0?tonNode.blockIdExt = liteServer.PartialBlockProof;
  check_init_block_stats_.queries_++;
  client_.send_query(
      ton::lite_api::liteServer_getBlockProof(1, create_tl_lite_block_id(from), create_tl_lite_block_id(to)),
      [this, from, to](auto r_block_proof) { this->on_init_block_proof(from, to, std::move(r_block_proof)); });
}

td::Result<std::unique_ptr<block::BlockProofChain>> LastBlock::process_block_proof(
    ton::BlockIdExt from,
    td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof>> r_block_proof) {
  TRY_RESULT(block_proof, std::move(r_block_proof));  //TODO: it is fatal?
  TRY_RESULT_PREFIX(chain, TRY_VM(process_block_proof(from, std::move(block_proof))),
                    TonlibError::ValidateBlockProof());
  return std::move(chain);
}

td::Result<std::unique_ptr<block::BlockProofChain>> LastBlock::process_block_proof(
    ton::BlockIdExt from, ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof> block_proof) {
  VLOG(last_block) << "Got proof FROM\n" << to_string(block_proof->from_) << "TO\n" << to_string(block_proof->to_);
  TRY_RESULT(chain, liteclient::deserialize_proof_chain(std::move(block_proof)));
  if (chain->from != from) {
    return td::Status::Error(PSLICE() << "block proof chain starts from block " << chain->from.to_str()
                                      << ", not from requested block " << from.to_str());
  }
  TRY_STATUS(chain->validate());
  return std::move(chain);
}

void LastBlock::update_state(block::BlockProofChain& chain) {
  // Update state_
  bool is_changed = false;
  is_changed |= update_mc_last_block(chain.to);
  if (chain.has_key_block) {
    is_changed |= update_mc_last_key_block(chain.key_blkid);
  }
  if (chain.has_utime) {
    update_utime(chain.last_utime);
  }
  if (is_changed) {
    save_state();
  }
}

void LastBlock::save_state() {
  if (check_init_block_state_ != QueryState::Done) {
    VLOG(last_block) << "skip `save_state` because `check_init_block` is not finished";
    return;
  }
  callback_->on_state_changed(state_);
}

void LastBlock::on_block_proof(
    ton::BlockIdExt from,
    td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof>> r_block_proof) {
  get_last_block_stats_.validate_.resume();
  auto r_chain = process_block_proof(from, std::move(r_block_proof));
  get_last_block_stats_.validate_.pause();
  if (r_chain.is_error()) {
    get_last_block_state_ = QueryState::Empty;
    VLOG(last_block) << "get_last_block: error " << r_chain.error();
    on_sync_error(r_chain.move_as_error_suffix("(during last block synchronization)"));
    return;
  }

  auto chain = r_chain.move_as_ok();
  CHECK(chain);
  update_state(*chain);
  if (chain->complete) {
    VLOG(last_block) << "get_last_block: done\n" << get_last_block_stats_;
    get_last_block_state_ = QueryState::Done;
    sync_loop();
  } else {
    do_get_last_block();
  }
}

void LastBlock::on_init_block_proof(
    ton::BlockIdExt from, ton::BlockIdExt to,
    td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_partialBlockProof>> r_block_proof) {
  check_init_block_stats_.validate_.resume();
  auto r_chain = process_block_proof(from, std::move(r_block_proof));
  check_init_block_stats_.validate_.pause();
  if (r_chain.is_error()) {
    check_init_block_state_ = QueryState::Empty;
    VLOG(last_block) << "check_init_block: error " << r_chain.error();
    on_sync_error(r_chain.move_as_error_suffix("(during check init block)"));
    return;
  }
  auto chain = r_chain.move_as_ok();
  CHECK(chain);
  update_state(*chain);
  if (chain->complete) {
    VLOG(last_block) << "check_init_block: done\n" << check_init_block_stats_;
    check_init_block_state_ = QueryState::Done;
    if (update_init_block(config_.init_block_id)) {
      save_state();
    }
    sync_loop();
  } else {
    do_check_init_block(chain->to, to);
  }
}

void LastBlock::on_masterchain_info(
    td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_masterchainInfo>> r_info) {
  if (r_info.is_ok()) {
    auto info = r_info.move_as_ok();
    update_zero_state(create_zero_state_id(info->init_), "masterchain info");
    // last block is not validated! Do not update it
    get_mc_info_state_ = QueryState::Done;
    VLOG(last_block) << "get_masterchain_info: done";
  } else {
    get_mc_info_state_ = QueryState::Empty;
    VLOG(last_block) << "get_masterchain_info: error " << r_info.error();
    LOG(WARNING) << "Failed liteServer_getMasterchainInfo " << r_info.error();
    on_sync_error(r_info.move_as_error());
  }
  sync_loop();
}

void LastBlock::update_zero_state(ton::ZeroStateIdExt zero_state_id, td::Slice source) {
  if (has_fatal_error()) {
    return;
  }
  if (!zero_state_id.is_valid()) {
    LOG(ERROR) << "Ignore invalid zero state update from " << source;
    return;
  }

  if (!state_.zero_state_id.is_valid()) {
    LOG(INFO) << "Init zerostate from " << source << ": " << zero_state_id.to_str();
    state_.zero_state_id = std::move(zero_state_id);
    return;
  }

  if (state_.zero_state_id == zero_state_id) {
    return;
  }

  on_fatal_error(TonlibError::ValidateZeroState(PSLICE() << "Masterchain zerostate mismatch: expected: "
                                                         << state_.zero_state_id.to_str() << ", found "
                                                         << zero_state_id.to_str() << " from " << source));
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
    //LOG(ERROR) << td::int64(state_.last_key_block_id.id.shard) << " "
    //<< td::base64_encode(state_.last_key_block_id.file_hash.as_slice()) << " "
    //<< td::base64_encode(state_.last_key_block_id.root_hash.as_slice());
    return true;
  }
  return false;
}

bool LastBlock::update_init_block(ton::BlockIdExt init_block_id) {
  if (has_fatal_error()) {
    return false;
  }
  if (!init_block_id.is_valid()) {
    LOG(ERROR) << "Ignore invalid init block";
    return false;
  }
  if (state_.init_block_id != init_block_id) {
    state_.init_block_id = init_block_id;
    LOG(INFO) << "Update init block id: " << state_.init_block_id.to_str();
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
  VLOG(last_block) << "sync: ok " << state_;
  for (auto& promise : promises_) {
    auto state = state_;
    promise.set_value(std::move(state));
  }
  promises_.clear();
}
void LastBlock::on_sync_error(td::Status status) {
  VLOG(last_block) << "sync: error " << status;
  for (auto& promise : promises_) {
    promise.set_error(status.clone());
  }
  promises_.clear();
}
void LastBlock::on_fatal_error(td::Status status) {
  VLOG(last_block) << "sync: fatal error " << status;
  fatal_error_ = std::move(status);
  on_sync_error(fatal_error_.clone());
}

bool LastBlock::has_fatal_error() const {
  return fatal_error_.is_error();
}
}  // namespace tonlib
