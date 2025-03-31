//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ScopeNotificationSettings.h"

#include "td/telegram/Global.h"

#include <limits>

namespace td {

telegram_api::object_ptr<telegram_api::inputPeerNotifySettings>
ScopeNotificationSettings::get_input_peer_notify_settings() const {
  int32 flags = telegram_api::inputPeerNotifySettings::MUTE_UNTIL_MASK |
                telegram_api::inputPeerNotifySettings::SHOW_PREVIEWS_MASK |
                telegram_api::inputPeerNotifySettings::STORIES_HIDE_SENDER_MASK;
  if (sound != nullptr) {
    flags |= telegram_api::inputPeerNotifySettings::SOUND_MASK;
  }
  if (story_sound != nullptr) {
    flags |= telegram_api::inputPeerNotifySettings::STORIES_SOUND_MASK;
  }
  if (!use_default_mute_stories) {
    flags |= telegram_api::inputPeerNotifySettings::STORIES_MUTED_MASK;
  }
  return telegram_api::make_object<telegram_api::inputPeerNotifySettings>(
      flags, show_preview, false, mute_until, get_input_notification_sound(sound), mute_stories, hide_story_sender,
      get_input_notification_sound(story_sound));
}

StringBuilder &operator<<(StringBuilder &string_builder, const ScopeNotificationSettings &notification_settings) {
  return string_builder << "[" << notification_settings.mute_until << ", " << notification_settings.sound << ", "
                        << notification_settings.show_preview << ", " << notification_settings.use_default_mute_stories
                        << ", " << notification_settings.mute_stories << ", " << notification_settings.story_sound
                        << ", " << notification_settings.hide_story_sender << ", "
                        << notification_settings.is_synchronized << ", "
                        << notification_settings.disable_pinned_message_notifications << ", "
                        << notification_settings.disable_mention_notifications << "]";
}

td_api::object_ptr<td_api::scopeNotificationSettings> get_scope_notification_settings_object(
    const ScopeNotificationSettings *notification_settings) {
  CHECK(notification_settings != nullptr);
  return td_api::make_object<td_api::scopeNotificationSettings>(
      max(0, notification_settings->mute_until - G()->unix_time()),
      get_notification_sound_ringtone_id(notification_settings->sound), notification_settings->show_preview,
      notification_settings->use_default_mute_stories, notification_settings->mute_stories,
      get_notification_sound_ringtone_id(notification_settings->story_sound), !notification_settings->hide_story_sender,
      notification_settings->disable_pinned_message_notifications,
      notification_settings->disable_mention_notifications);
}

static int32 get_mute_until(int32 mute_for) {
  if (mute_for <= 0) {
    return 0;
  }

  const int32 MAX_PRECISE_MUTE_FOR = 366 * 86400;
  int32 current_time = G()->unix_time();
  if (mute_for > MAX_PRECISE_MUTE_FOR || mute_for >= std::numeric_limits<int32>::max() - current_time) {
    return std::numeric_limits<int32>::max();
  }
  return mute_for + current_time;
}

Result<ScopeNotificationSettings> get_scope_notification_settings(
    td_api::object_ptr<td_api::scopeNotificationSettings> &&notification_settings) {
  if (notification_settings == nullptr) {
    return Status::Error(400, "New notification settings must be non-empty");
  }

  auto mute_until = get_mute_until(notification_settings->mute_for_);
  return ScopeNotificationSettings(
      mute_until, get_notification_sound(false, notification_settings->sound_id_), notification_settings->show_preview_,
      notification_settings->use_default_mute_stories_, notification_settings->mute_stories_,
      get_notification_sound(false, notification_settings->story_sound_id_), !notification_settings->show_story_sender_,
      notification_settings->disable_pinned_message_notifications_,
      notification_settings->disable_mention_notifications_);
}

ScopeNotificationSettings get_scope_notification_settings(tl_object_ptr<telegram_api::peerNotifySettings> &&settings,
                                                          bool old_disable_pinned_message_notifications,
                                                          bool old_disable_mention_notifications) {
  if (settings == nullptr) {
    return ScopeNotificationSettings();
  }
  auto mute_until = settings->mute_until_;
  if (mute_until <= G()->unix_time()) {
    mute_until = 0;
  }
  auto show_preview = settings->show_previews_;
  auto use_default_mute_stories = (settings->flags_ & telegram_api::peerNotifySettings::STORIES_MUTED_MASK) == 0;
  auto mute_stories = settings->stories_muted_;
  auto hide_story_sender = settings->stories_hide_sender_;
  return {mute_until,
          get_notification_sound(settings.get(), false),
          show_preview,
          use_default_mute_stories,
          mute_stories,
          get_notification_sound(settings.get(), true),
          hide_story_sender,
          old_disable_pinned_message_notifications,
          old_disable_mention_notifications};
}

}  // namespace td
