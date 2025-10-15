//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserPrivacySetting.h"
#include "td/telegram/UserPrivacySettingRule.h"

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Status.h"

#include <array>

namespace td {

class Td;

class PrivacyManager final : public Actor {
 public:
  PrivacyManager(Td *td, ActorShared<> parent);

  void get_privacy(tl_object_ptr<td_api::UserPrivacySetting> key,
                   Promise<tl_object_ptr<td_api::userPrivacySettingRules>> promise);

  void set_privacy(tl_object_ptr<td_api::UserPrivacySetting> key, tl_object_ptr<td_api::userPrivacySettingRules> rules,
                   Promise<Unit> promise);

  void on_update_privacy(tl_object_ptr<telegram_api::updatePrivacy> update);

  void allow_unpaid_messages(UserId user_id, bool refund_payments, Promise<Unit> &&promise);

 private:
  struct PrivacyInfo {
    UserPrivacySettingRules rules_;
    UserPrivacySettingRules pending_rules_;
    vector<Promise<tl_object_ptr<td_api::userPrivacySettingRules>>> get_promises_;
    vector<Promise<Unit>> set_promises_;
    bool has_set_query_ = false;
    bool is_synchronized_ = false;
  };

  void tear_down() final;

  PrivacyInfo &get_info(UserPrivacySetting key) {
    return info_[static_cast<size_t>(key.type())];
  }

  void on_get_user_privacy_settings(UserPrivacySetting user_privacy_setting,
                                    Result<UserPrivacySettingRules> r_privacy_rules);

  void set_privacy_impl(UserPrivacySetting user_privacy_setting, UserPrivacySettingRules &&privacy_rules,
                        Promise<Unit> &&promise);

  void on_set_user_privacy_settings(UserPrivacySetting user_privacy_setting,
                                    Result<UserPrivacySettingRules> r_privacy_rules, Promise<Unit> &&promise);

  void do_update_privacy(UserPrivacySetting user_privacy_setting, UserPrivacySettingRules &&privacy_rules,
                         bool from_update);

  std::array<PrivacyInfo, static_cast<size_t>(UserPrivacySetting::Type::Size)> info_;

  Td *td_;
  ActorShared<> parent_;
};

}  // namespace td
