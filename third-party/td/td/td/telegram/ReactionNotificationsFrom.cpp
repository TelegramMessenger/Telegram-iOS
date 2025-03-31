//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ReactionNotificationsFrom.h"

namespace td {

ReactionNotificationsFrom::ReactionNotificationsFrom(
    td_api::object_ptr<td_api::ReactionNotificationSource> &&notification_source) {
  if (notification_source == nullptr) {
    type_ = Type::None;
    return;
  }
  switch (notification_source->get_id()) {
    case td_api::reactionNotificationSourceNone::ID:
      type_ = Type::None;
      break;
    case td_api::reactionNotificationSourceContacts::ID:
      type_ = Type::Contacts;
      break;
    case td_api::reactionNotificationSourceAll::ID:
      type_ = Type::All;
      break;
    default:
      UNREACHABLE();
  }
}

ReactionNotificationsFrom::ReactionNotificationsFrom(
    telegram_api::object_ptr<telegram_api::ReactionNotificationsFrom> &&notifications_from) {
  if (notifications_from == nullptr) {
    type_ = Type::None;
    return;
  }
  switch (notifications_from->get_id()) {
    case telegram_api::reactionNotificationsFromContacts::ID:
      type_ = Type::Contacts;
      break;
    case telegram_api::reactionNotificationsFromAll::ID:
      type_ = Type::All;
      break;
    default:
      UNREACHABLE();
  }
}

td_api::object_ptr<td_api::ReactionNotificationSource>
ReactionNotificationsFrom::get_reaction_notification_source_object() const {
  switch (type_) {
    case Type::None:
      return td_api::make_object<td_api::reactionNotificationSourceNone>();
    case Type::Contacts:
      return td_api::make_object<td_api::reactionNotificationSourceContacts>();
    case Type::All:
      return td_api::make_object<td_api::reactionNotificationSourceAll>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

telegram_api::object_ptr<telegram_api::ReactionNotificationsFrom>
ReactionNotificationsFrom::get_input_reaction_notifications_from() const {
  switch (type_) {
    case Type::None:
      return nullptr;
    case Type::Contacts:
      return telegram_api::make_object<telegram_api::reactionNotificationsFromContacts>();
    case Type::All:
      return telegram_api::make_object<telegram_api::reactionNotificationsFromAll>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

bool operator==(const ReactionNotificationsFrom &lhs, const ReactionNotificationsFrom &rhs) {
  return lhs.type_ == rhs.type_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const ReactionNotificationsFrom &notifications_from) {
  switch (notifications_from.type_) {
    case ReactionNotificationsFrom::Type::None:
      return string_builder << "disabled";
    case ReactionNotificationsFrom::Type::Contacts:
      return string_builder << "contacts";
    case ReactionNotificationsFrom::Type::All:
      return string_builder << "all";
    default:
      UNREACHABLE();
      return string_builder;
  }
}

}  // namespace td
