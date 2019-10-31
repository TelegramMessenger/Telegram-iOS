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

#include "tonlib/Config.h"
#include "tonlib/ExtClient.h"

#include "td/utils/CancellationToken.h"
#include "td/utils/tl_helpers.h"

#include "block/mc-config.h"

namespace tonlib {
struct LastConfigState {
  std::shared_ptr<const block::Config> config;
};

td::StringBuilder& operator<<(td::StringBuilder& sb, const LastConfigState& state);

class LastConfig : public td::actor::Actor {
 public:
  class Callback {
   public:
    virtual ~Callback() {
    }
  };

  explicit LastConfig(ExtClientRef client, td::unique_ptr<Callback> callback);
  void get_last_config(td::Promise<LastConfigState> promise);

 private:
  td::unique_ptr<Callback> callback_;
  ExtClient client_;
  LastConfigState state_;

  enum class QueryState { Empty, Active, Done };
  QueryState get_config_state_{QueryState::Empty};

  std::vector<td::Promise<LastConfigState>> promises_;
  std::vector<td::int32> params_{18, 20, 21, 24, 25};

  void with_last_block(td::Result<LastBlockState> r_last_block);
  void on_config(td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_configInfo>> r_config);
  td::Status process_config(td::Result<ton::ton_api::object_ptr<ton::lite_api::liteServer_configInfo>> r_config);
  td::Status process_config_proof(ton::ton_api::object_ptr<ton::lite_api::liteServer_configInfo> config);

  void on_ok();
  void on_error(td::Status status);

  void loop() override;
  void tear_down() override;
};
}  // namespace tonlib
