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
#include "tonlib/LastConfig.h"

#include "tonlib/utils.h"

#include "ton/lite-tl.hpp"
#include "block/check-proof.h"
#include "block/mc-config.h"
#include "block/block-auto.h"

#include "lite-client/lite-client-common.h"

#include "LastBlock.h"

namespace tonlib {

// init_state <-> last_key_block
// state.valitated_init_state
// last_key_block ->
//
td::StringBuilder& operator<<(td::StringBuilder& sb, const LastConfigState& state) {
  return sb;
}

LastConfig::LastConfig(ExtClientRef client, td::unique_ptr<Callback> callback) : callback_(std::move(callback)) {
  client_.set_client(client);
  VLOG(last_block) << "State: " << state_;
}

void LastConfig::get_last_config(td::Promise<LastConfigState> promise) {
  if (promises_.empty() && get_config_state_ == QueryState::Done) {
    VLOG(last_config) << "start";
    VLOG(last_config) << "get_config: reset";
    get_config_state_ = QueryState::Empty;
  }

  promises_.push_back(std::move(promise));
  loop();
}

void LastConfig::with_last_block(td::Result<LastBlockState> r_last_block) {
  if (r_last_block.is_error()) {
    on_error(r_last_block.move_as_error());
    return;
  }

  auto last_block = r_last_block.move_as_ok();
  auto params = params_;
  client_.send_query(ton::lite_api::liteServer_getConfigParams(0, create_tl_lite_block_id(last_block.last_block_id),
                                                               std::move(params)),
                     [this](auto r_config) { this->on_config(std::move(r_config)); });
}

void LastConfig::on_config(td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_configInfo>> r_config) {
  auto status = process_config(std::move(r_config));
  if (status.is_ok()) {
    on_ok();
    get_config_state_ = QueryState::Done;
  } else {
    on_error(std::move(status));
    get_config_state_ = QueryState::Empty;
  }
}

td::Status LastConfig::process_config(
    td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_configInfo>> r_config) {
  TRY_RESULT(raw_config, std::move(r_config));
  TRY_STATUS_PREFIX(TRY_VM(process_config_proof(std::move(raw_config))), TonlibError::ValidateConfig());
  return td::Status::OK();
}

td::Status LastConfig::process_config_proof(ton::ton_api::object_ptr<ton::lite_api::liteServer_configInfo> raw_config) {
  auto blkid = create_block_id(raw_config->id_);
  if (!blkid.is_masterchain_ext()) {
    return td::Status::Error(PSLICE() << "reference block " << blkid.to_str()
                                      << " for the configuration is not a valid masterchain block");
  }
  TRY_RESULT(state, block::check_extract_state_proof(blkid, raw_config->state_proof_.as_slice(),
                                                     raw_config->config_proof_.as_slice()));
  TRY_RESULT(config, block::Config::extract_from_state(std::move(state), 0));

  for (auto i : params_) {
    VLOG(last_config) << "ConfigParam(" << i << ") = ";
    auto value = config->get_config_param(i);
    if (value.is_null()) {
      VLOG(last_config) << "(null)\n";
    } else {
      std::ostringstream os;
      if (i >= 0) {
        block::gen::ConfigParam{i}.print_ref(os, value);
        os << std::endl;
      }
      vm::load_cell_slice(value).print_rec(os);
      VLOG(last_config) << os.str();
    }
  }
  state_.config.reset(config.release());
  return td::Status::OK();
}

void LastConfig::loop() {
  if (promises_.empty()) {
    return;
  }

  if (get_config_state_ == QueryState::Empty) {
    VLOG(last_block) << "get_config: start";
    get_config_state_ = QueryState::Active;
    client_.with_last_block(
        [self = this](td::Result<LastBlockState> r_last_block) { self->with_last_block(std::move(r_last_block)); });
  }
}

void LastConfig::on_ok() {
  VLOG(last_block) << "ok " << state_;
  for (auto& promise : promises_) {
    auto state = state_;
    promise.set_value(std::move(state));
  }
  promises_.clear();
}

void LastConfig::on_error(td::Status status) {
  VLOG(last_config) << "error " << status;
  for (auto& promise : promises_) {
    promise.set_error(status.clone());
  }
  promises_.clear();
}

void LastConfig::tear_down() {
  on_error(TonlibError::Cancelled());
}

}  // namespace tonlib
