//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogBoostLinkInfo.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

#include <utility>

namespace td {

class Td;

class BoostManager final : public Actor {
 public:
  BoostManager(Td *td, ActorShared<> parent);

  td_api::object_ptr<td_api::chatBoostLevelFeatures> get_chat_boost_level_features_object(bool for_megagroup,
                                                                                          int32 level) const;

  td_api::object_ptr<td_api::chatBoostFeatures> get_chat_boost_features_object(bool for_megagroup) const;

  void get_boost_slots(Promise<td_api::object_ptr<td_api::chatBoostSlots>> &&promise);

  void get_dialog_boost_status(DialogId dialog_id, Promise<td_api::object_ptr<td_api::chatBoostStatus>> &&promise);

  void boost_dialog(DialogId dialog_id, vector<int32> slot_ids,
                    Promise<td_api::object_ptr<td_api::chatBoostSlots>> &&promise);

  Result<std::pair<string, bool>> get_dialog_boost_link(DialogId dialog_id);

  void get_dialog_boost_link_info(Slice url, Promise<DialogBoostLinkInfo> &&promise);

  td_api::object_ptr<td_api::chatBoostLinkInfo> get_chat_boost_link_info_object(const DialogBoostLinkInfo &info) const;

  void get_dialog_boosts(DialogId dialog_id, bool only_gift_codes, const string &offset, int32 limit,
                         Promise<td_api::object_ptr<td_api::foundChatBoosts>> &&promise);

  void get_user_dialog_boosts(DialogId dialog_id, UserId user_id,
                              Promise<td_api::object_ptr<td_api::foundChatBoosts>> &&promise);

  void on_update_dialog_boost(DialogId dialog_id, telegram_api::object_ptr<telegram_api::boost> &&boost);

 private:
  void tear_down() final;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
