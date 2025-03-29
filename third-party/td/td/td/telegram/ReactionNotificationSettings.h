//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/NotificationSound.h"
#include "td/telegram/ReactionNotificationsFrom.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class ReactionNotificationSettings {
  ReactionNotificationsFrom message_reactions_;
  ReactionNotificationsFrom story_reactions_;
  unique_ptr<NotificationSound> sound_;
  bool show_preview_ = true;

  friend bool operator==(const ReactionNotificationSettings &lhs, const ReactionNotificationSettings &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder,
                                   const ReactionNotificationSettings &notification_settings);

 public:
  ReactionNotificationSettings() = default;

  explicit ReactionNotificationSettings(
      td_api::object_ptr<td_api::reactionNotificationSettings> &&notification_settings);

  explicit ReactionNotificationSettings(
      telegram_api::object_ptr<telegram_api::reactionsNotifySettings> &&notify_settings);

  td_api::object_ptr<td_api::reactionNotificationSettings> get_reaction_notification_settings_object() const;

  telegram_api::object_ptr<telegram_api::reactionsNotifySettings> get_input_reactions_notify_settings() const;

  void update_default_notification_sound(const ReactionNotificationSettings &other);

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const ReactionNotificationSettings &lhs, const ReactionNotificationSettings &rhs);

inline bool operator!=(const ReactionNotificationSettings &lhs, const ReactionNotificationSettings &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const ReactionNotificationSettings &notification_settings);

}  // namespace td
