//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/NotificationGroupType.h"

namespace td {

bool is_database_notification_group_type(NotificationGroupType type) {
  switch (type) {
    case NotificationGroupType::Messages:
    case NotificationGroupType::Mentions:
    case NotificationGroupType::SecretChat:
      return true;
    case NotificationGroupType::Calls:
      return false;
    default:
      UNREACHABLE();
      return false;
  }
}

bool is_partial_notification_group_type(NotificationGroupType type) {
  switch (type) {
    case NotificationGroupType::Messages:
    case NotificationGroupType::Mentions:
      return true;
    case NotificationGroupType::SecretChat:
    case NotificationGroupType::Calls:
      return false;
    default:
      UNREACHABLE();
      return false;
  }
}

td_api::object_ptr<td_api::NotificationGroupType> get_notification_group_type_object(NotificationGroupType type) {
  switch (type) {
    case NotificationGroupType::Messages:
      return td_api::make_object<td_api::notificationGroupTypeMessages>();
    case NotificationGroupType::Mentions:
      return td_api::make_object<td_api::notificationGroupTypeMentions>();
    case NotificationGroupType::SecretChat:
      return td_api::make_object<td_api::notificationGroupTypeSecretChat>();
    case NotificationGroupType::Calls:
      return td_api::make_object<td_api::notificationGroupTypeCalls>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

NotificationGroupType get_notification_group_type(const td_api::object_ptr<td_api::NotificationGroupType> &type) {
  CHECK(type != nullptr);
  switch (type->get_id()) {
    case td_api::notificationGroupTypeMessages::ID:
      return NotificationGroupType::Messages;
    case td_api::notificationGroupTypeMentions::ID:
      return NotificationGroupType::Mentions;
    case td_api::notificationGroupTypeSecretChat::ID:
      return NotificationGroupType::SecretChat;
    case td_api::notificationGroupTypeCalls::ID:
      return NotificationGroupType::Calls;
    default:
      UNREACHABLE();
      return NotificationGroupType::Calls;
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, const NotificationGroupType &type) {
  switch (type) {
    case NotificationGroupType::Messages:
      return string_builder << "Messages";
    case NotificationGroupType::Mentions:
      return string_builder << "Mentions";
    case NotificationGroupType::SecretChat:
      return string_builder << "SecretChat";
    case NotificationGroupType::Calls:
      return string_builder << "Calls";
    default:
      UNREACHABLE();
      return string_builder;
  }
}

}  // namespace td
