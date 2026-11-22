//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/net/NetActor.h"
#include "td/telegram/net/NetQuery.h"
#include "td/telegram/net/NetQueryCreator.h"
#include "td/telegram/net/NetQueryDispatcher.h"
#include "td/telegram/net/PublicRsaKeySharedCdn.h"
#include "td/telegram/telegram_api.h"

#include "td/actor/actor.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/FloodControlStrict.h"

#include <memory>

namespace td {

class PublicRsaKeyWatchdog final : public NetActor {
 public:
  explicit PublicRsaKeyWatchdog(ActorShared<> parent);

  void add_public_rsa_key(std::shared_ptr<PublicRsaKeySharedCdn> key);

 private:
  ActorShared<> parent_;
  vector<std::shared_ptr<PublicRsaKeySharedCdn>> keys_;
  tl_object_ptr<telegram_api::cdnConfig> cdn_config_;
  FloodControlStrict flood_control_;
  bool has_query_{false};
  string current_version_;

  void start_up() final;
  void loop() final;

  void on_result(NetQueryPtr net_query) final;
  void sync(BufferSlice cdn_config_serialized);
  void sync_key(std::shared_ptr<PublicRsaKeySharedCdn> &key);
};

}  // namespace td
