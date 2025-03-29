//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/UserPrivacySettingRule.h"

#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/logging.h"

#include <algorithm>

namespace td {

void UserPrivacySettingRule::set_dialog_ids(Td *td, const vector<int64> &chat_ids) {
  dialog_ids_.clear();
  for (auto chat_id : chat_ids) {
    DialogId dialog_id(chat_id);
    if (!td->dialog_manager_->have_dialog_force(dialog_id, "UserPrivacySettingRule::set_dialog_ids")) {
      LOG(INFO) << "Ignore not found " << dialog_id;
      continue;
    }

    switch (dialog_id.get_type()) {
      case DialogType::Chat:
        dialog_ids_.push_back(dialog_id);
        break;
      case DialogType::Channel: {
        auto channel_id = dialog_id.get_channel_id();
        if (!td->chat_manager_->is_megagroup_channel(channel_id)) {
          LOG(INFO) << "Ignore broadcast " << channel_id;
          break;
        }
        dialog_ids_.push_back(dialog_id);
        break;
      }
      default:
        LOG(INFO) << "Ignore " << dialog_id;
    }
  }
}

UserPrivacySettingRule::UserPrivacySettingRule(Td *td, const td_api::UserPrivacySettingRule &rule) {
  switch (rule.get_id()) {
    case td_api::userPrivacySettingRuleAllowContacts::ID:
      type_ = Type::AllowContacts;
      break;
    case td_api::userPrivacySettingRuleAllowBots::ID:
      type_ = Type::AllowBots;
      break;
    case td_api::userPrivacySettingRuleAllowPremiumUsers::ID:
      type_ = Type::AllowPremium;
      break;
    case td_api::userPrivacySettingRuleAllowAll::ID:
      type_ = Type::AllowAll;
      break;
    case td_api::userPrivacySettingRuleAllowUsers::ID:
      type_ = Type::AllowUsers;
      user_ids_ = UserId::get_user_ids(static_cast<const td_api::userPrivacySettingRuleAllowUsers &>(rule).user_ids_);
      break;
    case td_api::userPrivacySettingRuleAllowChatMembers::ID:
      type_ = Type::AllowChatParticipants;
      set_dialog_ids(td, static_cast<const td_api::userPrivacySettingRuleAllowChatMembers &>(rule).chat_ids_);
      break;
    case td_api::userPrivacySettingRuleRestrictContacts::ID:
      type_ = Type::RestrictContacts;
      break;
    case td_api::userPrivacySettingRuleRestrictBots::ID:
      type_ = Type::RestrictBots;
      break;
    case td_api::userPrivacySettingRuleRestrictAll::ID:
      type_ = Type::RestrictAll;
      break;
    case td_api::userPrivacySettingRuleRestrictUsers::ID:
      type_ = Type::RestrictUsers;
      user_ids_ =
          UserId::get_user_ids(static_cast<const td_api::userPrivacySettingRuleRestrictUsers &>(rule).user_ids_);
      break;
    case td_api::userPrivacySettingRuleRestrictChatMembers::ID:
      type_ = Type::RestrictChatParticipants;
      set_dialog_ids(td, static_cast<const td_api::userPrivacySettingRuleRestrictChatMembers &>(rule).chat_ids_);
      break;
    default:
      UNREACHABLE();
  }
}

UserPrivacySettingRule::UserPrivacySettingRule(Td *td,
                                               const telegram_api::object_ptr<telegram_api::PrivacyRule> &rule) {
  CHECK(rule != nullptr);
  switch (rule->get_id()) {
    case telegram_api::privacyValueAllowContacts::ID:
      type_ = Type::AllowContacts;
      break;
    case telegram_api::privacyValueAllowBots::ID:
      type_ = Type::AllowBots;
      break;
    case telegram_api::privacyValueAllowPremium::ID:
      type_ = Type::AllowPremium;
      break;
    case telegram_api::privacyValueAllowCloseFriends::ID:
      type_ = Type::AllowCloseFriends;
      break;
    case telegram_api::privacyValueAllowAll::ID:
      type_ = Type::AllowAll;
      break;
    case telegram_api::privacyValueAllowUsers::ID:
      type_ = Type::AllowUsers;
      user_ids_ = UserId::get_user_ids(static_cast<const telegram_api::privacyValueAllowUsers &>(*rule).users_);
      break;
    case telegram_api::privacyValueAllowChatParticipants::ID:
      type_ = Type::AllowChatParticipants;
      set_dialog_ids_from_server(td,
                                 static_cast<const telegram_api::privacyValueAllowChatParticipants &>(*rule).chats_);
      break;
    case telegram_api::privacyValueDisallowContacts::ID:
      type_ = Type::RestrictContacts;
      break;
    case telegram_api::privacyValueDisallowBots::ID:
      type_ = Type::RestrictBots;
      break;
    case telegram_api::privacyValueDisallowAll::ID:
      type_ = Type::RestrictAll;
      break;
    case telegram_api::privacyValueDisallowUsers::ID:
      type_ = Type::RestrictUsers;
      user_ids_ = UserId::get_user_ids(static_cast<const telegram_api::privacyValueDisallowUsers &>(*rule).users_);
      break;
    case telegram_api::privacyValueDisallowChatParticipants::ID:
      type_ = Type::RestrictChatParticipants;
      set_dialog_ids_from_server(td,
                                 static_cast<const telegram_api::privacyValueDisallowChatParticipants &>(*rule).chats_);
      break;
    default:
      UNREACHABLE();
  }
  td::remove_if(user_ids_, [td](UserId user_id) {
    if (!td->user_manager_->have_user(user_id)) {
      LOG(ERROR) << "Receive unknown " << user_id;
      return true;
    }
    return false;
  });
}

void UserPrivacySettingRule::set_dialog_ids_from_server(Td *td, const vector<int64> &server_chat_ids) {
  dialog_ids_.clear();
  for (auto server_chat_id : server_chat_ids) {
    ChatId chat_id(server_chat_id);
    DialogId dialog_id(chat_id);
    if (!td->chat_manager_->have_chat(chat_id)) {
      ChannelId channel_id(server_chat_id);
      dialog_id = DialogId(channel_id);
      if (!td->chat_manager_->have_channel(channel_id)) {
        LOG(ERROR) << "Receive unknown group " << server_chat_id << " from the server";
        continue;
      }
    }
    td->dialog_manager_->force_create_dialog(dialog_id, "set_dialog_ids_from_server");
    dialog_ids_.push_back(dialog_id);
  }
}

td_api::object_ptr<td_api::UserPrivacySettingRule> UserPrivacySettingRule::get_user_privacy_setting_rule_object(
    Td *td) const {
  switch (type_) {
    case Type::AllowContacts:
      return make_tl_object<td_api::userPrivacySettingRuleAllowContacts>();
    case Type::AllowBots:
      return make_tl_object<td_api::userPrivacySettingRuleAllowBots>();
    case Type::AllowPremium:
      return make_tl_object<td_api::userPrivacySettingRuleAllowPremiumUsers>();
    case Type::AllowCloseFriends:
      LOG(ERROR) << "Have AllowCloseFriends rule";
      return make_tl_object<td_api::userPrivacySettingRuleAllowUsers>();
    case Type::AllowAll:
      return make_tl_object<td_api::userPrivacySettingRuleAllowAll>();
    case Type::AllowUsers:
      return make_tl_object<td_api::userPrivacySettingRuleAllowUsers>(
          td->user_manager_->get_user_ids_object(user_ids_, "userPrivacySettingRuleAllowUsers"));
    case Type::AllowChatParticipants:
      return make_tl_object<td_api::userPrivacySettingRuleAllowChatMembers>(
          td->dialog_manager_->get_chat_ids_object(dialog_ids_, "UserPrivacySettingRule"));
    case Type::RestrictContacts:
      return make_tl_object<td_api::userPrivacySettingRuleRestrictContacts>();
    case Type::RestrictBots:
      return make_tl_object<td_api::userPrivacySettingRuleRestrictBots>();
    case Type::RestrictAll:
      return make_tl_object<td_api::userPrivacySettingRuleRestrictAll>();
    case Type::RestrictUsers:
      return make_tl_object<td_api::userPrivacySettingRuleRestrictUsers>(
          td->user_manager_->get_user_ids_object(user_ids_, "userPrivacySettingRuleRestrictUsers"));
    case Type::RestrictChatParticipants:
      return make_tl_object<td_api::userPrivacySettingRuleRestrictChatMembers>(
          td->dialog_manager_->get_chat_ids_object(dialog_ids_, "UserPrivacySettingRule"));
    default:
      UNREACHABLE();
      return nullptr;
  }
}

telegram_api::object_ptr<telegram_api::InputPrivacyRule> UserPrivacySettingRule::get_input_privacy_rule(Td *td) const {
  switch (type_) {
    case Type::AllowContacts:
      return make_tl_object<telegram_api::inputPrivacyValueAllowContacts>();
    case Type::AllowBots:
      return make_tl_object<telegram_api::inputPrivacyValueAllowBots>();
    case Type::AllowPremium:
      return make_tl_object<telegram_api::inputPrivacyValueAllowPremium>();
    case Type::AllowCloseFriends:
      return make_tl_object<telegram_api::inputPrivacyValueAllowCloseFriends>();
    case Type::AllowAll:
      return make_tl_object<telegram_api::inputPrivacyValueAllowAll>();
    case Type::AllowUsers:
      return make_tl_object<telegram_api::inputPrivacyValueAllowUsers>(get_input_users(td));
    case Type::AllowChatParticipants:
      return make_tl_object<telegram_api::inputPrivacyValueAllowChatParticipants>(get_input_chat_ids(td));
    case Type::RestrictContacts:
      return make_tl_object<telegram_api::inputPrivacyValueDisallowContacts>();
    case Type::RestrictBots:
      return make_tl_object<telegram_api::inputPrivacyValueDisallowBots>();
    case Type::RestrictAll:
      return make_tl_object<telegram_api::inputPrivacyValueDisallowAll>();
    case Type::RestrictUsers:
      return make_tl_object<telegram_api::inputPrivacyValueDisallowUsers>(get_input_users(td));
    case Type::RestrictChatParticipants:
      return make_tl_object<telegram_api::inputPrivacyValueDisallowChatParticipants>(get_input_chat_ids(td));
    default:
      UNREACHABLE();
  }
}

vector<telegram_api::object_ptr<telegram_api::InputUser>> UserPrivacySettingRule::get_input_users(Td *td) const {
  vector<telegram_api::object_ptr<telegram_api::InputUser>> result;
  for (auto user_id : user_ids_) {
    auto r_input_user = td->user_manager_->get_input_user(user_id);
    if (r_input_user.is_ok()) {
      result.push_back(r_input_user.move_as_ok());
    } else {
      LOG(INFO) << "Have no access to " << user_id;
    }
  }
  return result;
}

vector<int64> UserPrivacySettingRule::get_input_chat_ids(Td *td) const {
  vector<int64> result;
  for (auto dialog_id : dialog_ids_) {
    switch (dialog_id.get_type()) {
      case DialogType::Chat:
        result.push_back(dialog_id.get_chat_id().get());
        break;
      case DialogType::Channel:
        result.push_back(dialog_id.get_channel_id().get());
        break;
      default:
        UNREACHABLE();
    }
  }
  return result;
}

vector<UserId> UserPrivacySettingRule::get_restricted_user_ids() const {
  if (type_ == Type::RestrictUsers) {
    return user_ids_;
  }
  return {};
}

void UserPrivacySettingRule::add_dependencies(Dependencies &dependencies) const {
  for (auto user_id : user_ids_) {
    dependencies.add(user_id);
  }
  for (auto dialog_id : dialog_ids_) {
    dependencies.add_dialog_and_dependencies(dialog_id);
  }
}

UserPrivacySettingRules UserPrivacySettingRules::get_user_privacy_setting_rules(
    Td *td, telegram_api::object_ptr<telegram_api::account_privacyRules> rules) {
  td->user_manager_->on_get_users(std::move(rules->users_), "on get privacy rules");
  td->chat_manager_->on_get_chats(std::move(rules->chats_), "on get privacy rules");
  return get_user_privacy_setting_rules(td, std::move(rules->rules_));
}

UserPrivacySettingRules UserPrivacySettingRules::get_user_privacy_setting_rules(
    Td *td, vector<telegram_api::object_ptr<telegram_api::PrivacyRule>> rules) {
  UserPrivacySettingRules result;
  for (auto &rule : rules) {
    result.rules_.push_back(UserPrivacySettingRule(td, std::move(rule)));
  }
  if (!result.rules_.empty() && result.rules_.back().type_ == UserPrivacySettingRule::Type::RestrictAll) {
    result.rules_.pop_back();
  }
  return result;
}

Result<UserPrivacySettingRules> UserPrivacySettingRules::get_user_privacy_setting_rules(
    Td *td, td_api::object_ptr<td_api::userPrivacySettingRules> rules) {
  if (rules == nullptr) {
    return Status::Error(400, "UserPrivacySettingRules must be non-empty");
  }
  UserPrivacySettingRules result;
  for (auto &rule : rules->rules_) {
    if (rule == nullptr) {
      return Status::Error(400, "UserPrivacySettingRule must be non-empty");
    }
    result.rules_.emplace_back(td, *rule);
  }
  return result;
}

Result<UserPrivacySettingRules> UserPrivacySettingRules::get_user_privacy_setting_rules(
    Td *td, td_api::object_ptr<td_api::StoryPrivacySettings> settings) {
  if (settings == nullptr) {
    return Status::Error(400, "StoryPrivacySettings must be non-empty");
  }
  UserPrivacySettingRules result;
  switch (settings->get_id()) {
    case td_api::storyPrivacySettingsEveryone::ID: {
      auto user_ids = std::move(static_cast<td_api::storyPrivacySettingsEveryone &>(*settings).except_user_ids_);
      if (!user_ids.empty()) {
        result.rules_.emplace_back(td, td_api::userPrivacySettingRuleRestrictUsers(std::move(user_ids)));
      }
      result.rules_.emplace_back(td, td_api::userPrivacySettingRuleAllowAll());
      break;
    }
    case td_api::storyPrivacySettingsContacts::ID: {
      auto user_ids = std::move(static_cast<td_api::storyPrivacySettingsContacts &>(*settings).except_user_ids_);
      if (!user_ids.empty()) {
        result.rules_.emplace_back(td, td_api::userPrivacySettingRuleRestrictUsers(std::move(user_ids)));
      }
      result.rules_.emplace_back(td, td_api::userPrivacySettingRuleAllowContacts());
      break;
    }
    case td_api::storyPrivacySettingsCloseFriends::ID: {
      UserPrivacySettingRule rule;
      rule.type_ = UserPrivacySettingRule::Type::AllowCloseFriends;
      result.rules_.push_back(std::move(rule));
      break;
    }
    case td_api::storyPrivacySettingsSelectedUsers::ID: {
      auto user_ids = std::move(static_cast<td_api::storyPrivacySettingsSelectedUsers &>(*settings).user_ids_);
      result.rules_.emplace_back(td, td_api::userPrivacySettingRuleAllowUsers(std::move(user_ids)));
      break;
    }
    default:
      UNREACHABLE();
  }
  return result;
}

td_api::object_ptr<td_api::userPrivacySettingRules> UserPrivacySettingRules::get_user_privacy_setting_rules_object(
    Td *td) const {
  return make_tl_object<td_api::userPrivacySettingRules>(
      transform(rules_, [td](const auto &rule) { return rule.get_user_privacy_setting_rule_object(td); }));
}

td_api::object_ptr<td_api::StoryPrivacySettings> UserPrivacySettingRules::get_story_privacy_settings_object(
    Td *td) const {
  if (rules_.empty()) {
    return nullptr;
  }
  if (rules_.size() == 1u && rules_[0].type_ == UserPrivacySettingRule::Type::AllowAll) {
    return td_api::make_object<td_api::storyPrivacySettingsEveryone>();
  }
  if (rules_.size() == 2u && rules_[0].type_ == UserPrivacySettingRule::Type::RestrictUsers &&
      rules_[1].type_ == UserPrivacySettingRule::Type::AllowAll) {
    return td_api::make_object<td_api::storyPrivacySettingsEveryone>(
        td->user_manager_->get_user_ids_object(rules_[0].user_ids_, "storyPrivacySettingsEveryone"));
  }
  if (rules_.size() == 1u && rules_[0].type_ == UserPrivacySettingRule::Type::AllowContacts) {
    return td_api::make_object<td_api::storyPrivacySettingsContacts>();
  }
  if (rules_.size() == 2u && rules_[0].type_ == UserPrivacySettingRule::Type::RestrictUsers &&
      rules_[1].type_ == UserPrivacySettingRule::Type::AllowContacts) {
    return td_api::make_object<td_api::storyPrivacySettingsContacts>(
        td->user_manager_->get_user_ids_object(rules_[0].user_ids_, "storyPrivacySettingsContacts"));
  }
  if (rules_.size() == 1u && rules_[0].type_ == UserPrivacySettingRule::Type::AllowCloseFriends) {
    return td_api::make_object<td_api::storyPrivacySettingsCloseFriends>();
  }
  if (rules_.size() == 1u && rules_[0].type_ == UserPrivacySettingRule::Type::AllowUsers) {
    return td_api::make_object<td_api::storyPrivacySettingsSelectedUsers>(
        td->user_manager_->get_user_ids_object(rules_[0].user_ids_, "storyPrivacySettingsSelectedUsers"));
  }
  return td_api::make_object<td_api::storyPrivacySettingsSelectedUsers>();
}

vector<telegram_api::object_ptr<telegram_api::InputPrivacyRule>> UserPrivacySettingRules::get_input_privacy_rules(
    Td *td) const {
  auto result = transform(rules_, [td](const auto &rule) { return rule.get_input_privacy_rule(td); });
  if (!result.empty() && result.back()->get_id() == telegram_api::inputPrivacyValueDisallowAll::ID) {
    result.pop_back();
  }
  return result;
}

vector<UserId> UserPrivacySettingRules::get_restricted_user_ids() const {
  vector<UserId> result;
  for (auto &rule : rules_) {
    combine(result, rule.get_restricted_user_ids());
  }
  std::sort(result.begin(), result.end(), [](UserId lhs, UserId rhs) { return lhs.get() < rhs.get(); });
  result.erase(std::unique(result.begin(), result.end()), result.end());
  return result;
}

void UserPrivacySettingRules::add_dependencies(Dependencies &dependencies) const {
  for (auto &rule : rules_) {
    rule.add_dependencies(dependencies);
  }
}

}  // namespace td
