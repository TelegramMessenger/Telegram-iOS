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

class DialogNotificationSettings {
 public:
  int32 mute_until = 0;
  unique_ptr<NotificationSound> sound;
  unique_ptr<NotificationSound> story_sound;
  bool show_preview = true;
  bool mute_stories = false;
  bool hide_story_sender = false;
  bool silent_send_message = false;
  bool use_default_mute_until = true;
  bool use_default_show_preview = true;
  bool use_default_mute_stories = true;
  bool use_default_hide_story_sender = true;
  bool is_use_default_fixed = true;
  bool is_secret_chat_show_preview_fixed = false;
  bool is_synchronized = false;

  // local settings
  bool use_default_disable_pinned_message_notifications = true;
  bool disable_pinned_message_notifications = false;
  bool use_default_disable_mention_notifications = true;
  bool disable_mention_notifications = false;

  DialogNotificationSettings() = default;

  DialogNotificationSettings(bool use_default_mute_until, int32 mute_until, unique_ptr<NotificationSound> &&sound,
                             bool use_default_show_preview, bool show_preview, bool use_default_mute_stories,
                             bool mute_stories, unique_ptr<NotificationSound> &&story_sound,
                             bool use_default_hide_story_sender, bool hide_story_sender, bool silent_send_message,
                             bool use_default_disable_pinned_message_notifications,
                             bool disable_pinned_message_notifications, bool use_default_disable_mention_notifications,
                             bool disable_mention_notifications)
      : mute_until(mute_until)
      , sound(std::move(sound))
      , story_sound(std::move(story_sound))
      , show_preview(show_preview)
      , mute_stories(mute_stories)
      , hide_story_sender(hide_story_sender)
      , silent_send_message(silent_send_message)
      , use_default_mute_until(use_default_mute_until)
      , use_default_show_preview(use_default_show_preview)
      , use_default_mute_stories(use_default_mute_stories)
      , use_default_hide_story_sender(use_default_hide_story_sender)
      , is_synchronized(true)
      , use_default_disable_pinned_message_notifications(use_default_disable_pinned_message_notifications)
      , disable_pinned_message_notifications(disable_pinned_message_notifications)
      , use_default_disable_mention_notifications(use_default_disable_mention_notifications)
      , disable_mention_notifications(disable_mention_notifications) {
  }

  telegram_api::object_ptr<telegram_api::inputPeerNotifySettings> get_input_peer_notify_settings() const;

  DialogNotificationSettings clone_for_secret_chat() const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const DialogNotificationSettings &notification_settings);

td_api::object_ptr<td_api::chatNotificationSettings> get_chat_notification_settings_object(
    const DialogNotificationSettings *notification_settings);

Result<DialogNotificationSettings> get_dialog_notification_settings(
    td_api::object_ptr<td_api::chatNotificationSettings> &&notification_settings,
    const DialogNotificationSettings *old_settings);

DialogNotificationSettings get_dialog_notification_settings(tl_object_ptr<telegram_api::peerNotifySettings> &&settings,
                                                            const DialogNotificationSettings *old_settings);

bool are_default_dialog_notification_settings(const DialogNotificationSettings &settings, bool compare_sound);

bool are_default_story_notification_settings(const DialogNotificationSettings &settings);

struct NeedUpdateDialogNotificationSettings {
  bool need_update_server = false;
  bool need_update_local = false;
  bool are_changed = false;
};
NeedUpdateDialogNotificationSettings need_update_dialog_notification_settings(
    const DialogNotificationSettings *current_settings, const DialogNotificationSettings &new_settings);

}  // namespace td
