//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"

namespace td {

class Td;

class GlobalPrivacySettings {
  enum class SetType : int32 { None, Archive, ReadDate, NewChat };
  SetType set_type_ = SetType::None;
  bool archive_and_mute_new_noncontact_peers_ = false;
  bool keep_archived_unmuted_ = false;
  bool keep_archived_folders_ = false;
  bool hide_read_marks_ = false;
  bool new_noncontact_peers_require_premium_ = false;
  int64 noncontact_peers_paid_star_count_ = 0;

  void apply_changes(const GlobalPrivacySettings &set_settings);

 public:
  explicit GlobalPrivacySettings(telegram_api::object_ptr<telegram_api::globalPrivacySettings> &&settings);

  explicit GlobalPrivacySettings(td_api::object_ptr<td_api::archiveChatListSettings> &&settings);

  explicit GlobalPrivacySettings(td_api::object_ptr<td_api::readDatePrivacySettings> &&settings);

  explicit GlobalPrivacySettings(td_api::object_ptr<td_api::newChatPrivacySettings> &&settings);

  telegram_api::object_ptr<telegram_api::globalPrivacySettings> get_input_global_privacy_settings() const;

  td_api::object_ptr<td_api::archiveChatListSettings> get_archive_chat_list_settings_object() const;

  td_api::object_ptr<td_api::readDatePrivacySettings> get_read_date_privacy_settings_object() const;

  td_api::object_ptr<td_api::newChatPrivacySettings> get_new_chat_privacy_settings_object() const;

  static void get_global_privacy_settings(Td *td, Promise<GlobalPrivacySettings> &&promise);

  static void set_global_privacy_settings(Td *td, GlobalPrivacySettings settings, Promise<Unit> &&promise);
};

}  // namespace td
