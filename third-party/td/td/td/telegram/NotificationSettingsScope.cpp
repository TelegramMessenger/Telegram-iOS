//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/NotificationSettingsScope.h"

namespace td {

StringBuilder &operator<<(StringBuilder &string_builder, NotificationSettingsScope scope) {
  switch (scope) {
    case NotificationSettingsScope::Private:
      return string_builder << "notification settings for private chats";
    case NotificationSettingsScope::Group:
      return string_builder << "notification settings for group chats";
    case NotificationSettingsScope::Channel:
      return string_builder << "notification settings for channel chats";
    default:
      UNREACHABLE();
      return string_builder;
  }
}

td_api::object_ptr<td_api::NotificationSettingsScope> get_notification_settings_scope_object(
    NotificationSettingsScope scope) {
  switch (scope) {
    case NotificationSettingsScope::Private:
      return td_api::make_object<td_api::notificationSettingsScopePrivateChats>();
    case NotificationSettingsScope::Group:
      return td_api::make_object<td_api::notificationSettingsScopeGroupChats>();
    case NotificationSettingsScope::Channel:
      return td_api::make_object<td_api::notificationSettingsScopeChannelChats>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

telegram_api::object_ptr<telegram_api::InputNotifyPeer> get_input_notify_peer(NotificationSettingsScope scope) {
  switch (scope) {
    case NotificationSettingsScope::Private:
      return telegram_api::make_object<telegram_api::inputNotifyUsers>();
    case NotificationSettingsScope::Group:
      return telegram_api::make_object<telegram_api::inputNotifyChats>();
    case NotificationSettingsScope::Channel:
      return telegram_api::make_object<telegram_api::inputNotifyBroadcasts>();
    default:
      return nullptr;
  }
}

NotificationSettingsScope get_notification_settings_scope(
    const td_api::object_ptr<td_api::NotificationSettingsScope> &scope) {
  CHECK(scope != nullptr);
  switch (scope->get_id()) {
    case td_api::notificationSettingsScopePrivateChats::ID:
      return NotificationSettingsScope::Private;
    case td_api::notificationSettingsScopeGroupChats::ID:
      return NotificationSettingsScope::Group;
    case td_api::notificationSettingsScopeChannelChats::ID:
      return NotificationSettingsScope::Channel;
    default:
      UNREACHABLE();
      return NotificationSettingsScope::Private;
  }
}

}  // namespace td
