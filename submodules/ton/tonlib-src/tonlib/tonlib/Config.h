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
#pragma once
#include "adnl/adnl-node-id.hpp"
#include "td/utils/port/IPAddress.h"
#include "ton/ton-types.h"

namespace tonlib {
struct Config {
  struct LiteClient {
    ton::adnl::AdnlNodeIdFull adnl_id;
    td::IPAddress address;
  };
  ton::BlockIdExt zero_state_id;
  ton::BlockIdExt init_block_id;
  std::vector<LiteClient> lite_clients;
  static td::Result<Config> parse(std::string str);
};
}  // namespace tonlib
