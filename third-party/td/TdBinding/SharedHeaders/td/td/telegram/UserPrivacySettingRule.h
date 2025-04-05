//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/tl_helpers.h"

namespace td {

class Dependencies;
class Td;

class UserPrivacySettingRule {
 public:
  UserPrivacySettingRule() = default;

  UserPrivacySettingRule(Td *td, const td_api::UserPrivacySettingRule &rule);

  UserPrivacySettingRule(Td *td, const telegram_api::object_ptr<telegram_api::PrivacyRule> &rule);

  td_api::object_ptr<td_api::UserPrivacySettingRule> get_user_privacy_setting_rule_object(Td *td) const;

  telegram_api::object_ptr<telegram_api::InputPrivacyRule> get_input_privacy_rule(Td *td) const;

  bool operator==(const UserPrivacySettingRule &other) const {
    return type_ == other.type_ && user_ids_ == other.user_ids_ && dialog_ids_ == other.dialog_ids_;
  }

  vector<UserId> get_restricted_user_ids() const;

  void add_dependencies(Dependencies &dependencies) const;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(type_, storer);
    if (type_ == Type::AllowUsers || type_ == Type::RestrictUsers) {
      td::store(user_ids_, storer);
    }
    if (type_ == Type::AllowChatParticipants || type_ == Type::RestrictChatParticipants) {
      td::store(dialog_ids_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(type_, parser);
    if (type_ == Type::AllowUsers || type_ == Type::RestrictUsers) {
      td::parse(user_ids_, parser);
      for (auto user_id : user_ids_) {
        if (!user_id.is_valid()) {
          parser.set_error("Failed to parse user identifiers");
        }
      }
    } else if (type_ == Type::AllowChatParticipants || type_ == Type::RestrictChatParticipants) {
      td::parse(dialog_ids_, parser);
      for (auto dialog_id : dialog_ids_) {
        auto dialog_type = dialog_id.get_type();
        if (!dialog_id.is_valid() || (dialog_type != DialogType::Chat && dialog_type != DialogType::Channel)) {
          parser.set_error("Failed to parse chat identifiers");
        }
      }
    } else if (type_ != Type::AllowContacts && type_ != Type::AllowBots && type_ != Type::AllowPremium &&
               type_ != Type::AllowCloseFriends && type_ != Type::AllowAll && type_ != Type::RestrictContacts &&
               type_ != Type::RestrictBots && type_ != Type::RestrictAll) {
      parser.set_error("Invalid privacy rule type");
    }
  }

 private:
  enum class Type : int32 {
    AllowContacts,
    AllowCloseFriends,
    AllowAll,
    AllowUsers,
    AllowChatParticipants,
    RestrictContacts,
    RestrictAll,
    RestrictUsers,
    RestrictChatParticipants,
    AllowPremium,
    AllowBots,
    RestrictBots
  } type_ = Type::RestrictAll;

  friend class UserPrivacySettingRules;

  vector<UserId> user_ids_;
  vector<DialogId> dialog_ids_;

  vector<telegram_api::object_ptr<telegram_api::InputUser>> get_input_users(Td *td) const;

  vector<int64> get_input_chat_ids(Td *td) const;

  void set_dialog_ids(Td *td, const vector<int64> &chat_ids);

  void set_dialog_ids_from_server(Td *td, const vector<int64> &chat_ids);
};

class UserPrivacySettingRules {
 public:
  UserPrivacySettingRules() = default;

  static UserPrivacySettingRules get_user_privacy_setting_rules(
      Td *td, telegram_api::object_ptr<telegram_api::account_privacyRules> rules);

  static UserPrivacySettingRules get_user_privacy_setting_rules(
      Td *td, vector<telegram_api::object_ptr<telegram_api::PrivacyRule>> rules);

  static Result<UserPrivacySettingRules> get_user_privacy_setting_rules(
      Td *td, td_api::object_ptr<td_api::userPrivacySettingRules> rules);

  static Result<UserPrivacySettingRules> get_user_privacy_setting_rules(
      Td *td, td_api::object_ptr<td_api::StoryPrivacySettings> settings);

  td_api::object_ptr<td_api::userPrivacySettingRules> get_user_privacy_setting_rules_object(Td *td) const;

  td_api::object_ptr<td_api::StoryPrivacySettings> get_story_privacy_settings_object(Td *td) const;

  vector<telegram_api::object_ptr<telegram_api::InputPrivacyRule>> get_input_privacy_rules(Td *td) const;

  bool operator==(const UserPrivacySettingRules &other) const {
    return rules_ == other.rules_;
  }

  bool operator!=(const UserPrivacySettingRules &other) const {
    return !(rules_ == other.rules_);
  }

  vector<UserId> get_restricted_user_ids() const;

  void add_dependencies(Dependencies &dependencies) const;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(rules_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(rules_, parser);
  }

 private:
  vector<UserPrivacySettingRule> rules_;
};

}  // namespace td
