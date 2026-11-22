//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/NotificationSound.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class ScopeNotificationSettings {
 public:
  int32 mute_until = 0;
  unique_ptr<NotificationSound> sound;
  unique_ptr<NotificationSound> story_sound;
  bool show_preview = true;
  bool use_default_mute_stories = true;
  bool mute_stories = false;
  bool hide_story_sender = false;
  bool is_synchronized = false;

  // local settings
  bool disable_pinned_message_notifications = false;
  bool disable_mention_notifications = false;

  ScopeNotificationSettings() = default;

  ScopeNotificationSettings(int32 mute_until, unique_ptr<NotificationSound> &&sound, bool show_preview,
                            bool use_default_mute_stories, bool mute_stories,
                            unique_ptr<NotificationSound> &&story_sound, bool hide_story_sender,
                            bool disable_pinned_message_notifications, bool disable_mention_notifications)
      : mute_until(mute_until)
      , sound(std::move(sound))
      , story_sound(std::move(story_sound))
      , show_preview(show_preview)
      , use_default_mute_stories(use_default_mute_stories)
      , mute_stories(mute_stories)
      , hide_story_sender(hide_story_sender)
      , is_synchronized(true)
      , disable_pinned_message_notifications(disable_pinned_message_notifications)
      , disable_mention_notifications(disable_mention_notifications) {
  }

  telegram_api::object_ptr<telegram_api::inputPeerNotifySettings> get_input_peer_notify_settings() const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const ScopeNotificationSettings &notification_settings);

td_api::object_ptr<td_api::scopeNotificationSettings> get_scope_notification_settings_object(
    const ScopeNotificationSettings *notification_settings);

Result<ScopeNotificationSettings> get_scope_notification_settings(
    td_api::object_ptr<td_api::scopeNotificationSettings> &&notification_settings);

ScopeNotificationSettings get_scope_notification_settings(tl_object_ptr<telegram_api::peerNotifySettings> &&settings,
                                                          bool old_disable_pinned_message_notifications,
                                                          bool old_disable_mention_notifications);

}  // namespace td
