//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChainId.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/net/NetQueryStats.h"
#include "td/telegram/UniqueId.h"

#include "td/utils/common.h"
#include "td/utils/ObjectPool.h"

#include <memory>

namespace td {

namespace telegram_api {
class Function;
}  // namespace telegram_api

class NetQueryCreator {
 public:
  explicit NetQueryCreator(std::shared_ptr<NetQueryStats> net_query_stats);

  void stop_check() {
    object_pool_.set_check_empty(false);
  }

  NetQueryPtr create(const telegram_api::Function &function, vector<ChainId> chain_ids = {}, DcId dc_id = DcId::main(),
                     NetQuery::Type type = NetQuery::Type::Common);

  NetQueryPtr create_unauth(const telegram_api::Function &function, DcId dc_id = DcId::main()) {
    return create(UniqueId::next(), nullptr, function, {}, dc_id, NetQuery::Type::Common, NetQuery::AuthFlag::Off);
  }

  NetQueryPtr create_with_prefix(const telegram_api::object_ptr<telegram_api::Function> &prefix,
                                 const telegram_api::Function &function, DcId dc_id, vector<ChainId> chain_ids = {},
                                 NetQuery::Type type = NetQuery::Type::Common);

  NetQueryPtr create(uint64 id, const telegram_api::object_ptr<telegram_api::Function> &prefix,
                     const telegram_api::Function &function, vector<ChainId> &&chain_ids, DcId dc_id,
                     NetQuery::Type type, NetQuery::AuthFlag auth_flag);

 private:
  std::shared_ptr<NetQueryStats> net_query_stats_;
  ObjectPool<NetQuery> object_pool_;
  int32 current_scheduler_id_ = 0;
};

}  // namespace td
