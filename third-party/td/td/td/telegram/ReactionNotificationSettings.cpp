//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ReactionNotificationSettings.h"

namespace td {

ReactionNotificationSettings::ReactionNotificationSettings(
    td_api::object_ptr<td_api::reactionNotificationSettings> &&notification_settings) {
  if (notification_settings == nullptr) {
    return;
  }
  message_reactions_ = ReactionNotificationsFrom(std::move(notification_settings->message_reaction_source_));
  story_reactions_ = ReactionNotificationsFrom(std::move(notification_settings->story_reaction_source_));
  sound_ = get_notification_sound(false, notification_settings->sound_id_);
  show_preview_ = notification_settings->show_preview_;
}

ReactionNotificationSettings::ReactionNotificationSettings(
    telegram_api::object_ptr<telegram_api::reactionsNotifySettings> &&notify_settings) {
  if (notify_settings == nullptr) {
    return;
  }
  message_reactions_ = ReactionNotificationsFrom(std::move(notify_settings->messages_notify_from_));
  story_reactions_ = ReactionNotificationsFrom(std::move(notify_settings->stories_notify_from_));
  sound_ = get_notification_sound(notify_settings->sound_.get());
  show_preview_ = notify_settings->show_previews_;
}

td_api::object_ptr<td_api::reactionNotificationSettings>
ReactionNotificationSettings::get_reaction_notification_settings_object() const {
  return td_api::make_object<td_api::reactionNotificationSettings>(
      message_reactions_.get_reaction_notification_source_object(),
      story_reactions_.get_reaction_notification_source_object(), get_notification_sound_ringtone_id(sound_),
      show_preview_);
}

telegram_api::object_ptr<telegram_api::reactionsNotifySettings>
ReactionNotificationSettings::get_input_reactions_notify_settings() const {
  int32 flags = 0;
  auto messages_notify_from = message_reactions_.get_input_reaction_notifications_from();
  if (messages_notify_from != nullptr) {
    flags |= telegram_api::reactionsNotifySettings::MESSAGES_NOTIFY_FROM_MASK;
  }
  auto stories_notify_from = story_reactions_.get_input_reaction_notifications_from();
  if (stories_notify_from != nullptr) {
    flags |= telegram_api::reactionsNotifySettings::STORIES_NOTIFY_FROM_MASK;
  }
  return telegram_api::make_object<telegram_api::reactionsNotifySettings>(
      flags, std::move(messages_notify_from), std::move(stories_notify_from),
      get_input_notification_sound(sound_, true), show_preview_);
}

void ReactionNotificationSettings::update_default_notification_sound(const ReactionNotificationSettings &other) {
  if (is_notification_sound_default(sound_) && is_notification_sound_default(other.sound_)) {
    sound_ = dup_notification_sound(other.sound_);
  }
}

bool operator==(const ReactionNotificationSettings &lhs, const ReactionNotificationSettings &rhs) {
  return lhs.message_reactions_ == rhs.message_reactions_ && lhs.story_reactions_ == rhs.story_reactions_ &&
         are_equivalent_notification_sounds(lhs.sound_, rhs.sound_) && lhs.show_preview_ == rhs.show_preview_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const ReactionNotificationSettings &notification_settings) {
  return string_builder << "ReactionNotificationSettings[messages: " << notification_settings.message_reactions_
                        << ", stories: " << notification_settings.story_reactions_
                        << ", sound: " << notification_settings.sound_
                        << ", show_preview: " << notification_settings.show_preview_ << ']';
}

}  // namespace td
