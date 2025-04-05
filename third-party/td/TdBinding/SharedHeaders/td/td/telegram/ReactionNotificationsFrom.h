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
#include "td/utils/StringBuilder.h"

namespace td {

class ReactionNotificationsFrom {
  enum class Type : int32 { None, Contacts, All };
  Type type_ = Type::Contacts;

  friend bool operator==(const ReactionNotificationsFrom &lhs, const ReactionNotificationsFrom &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const ReactionNotificationsFrom &notifications_from);

 public:
  ReactionNotificationsFrom() = default;

  explicit ReactionNotificationsFrom(td_api::object_ptr<td_api::ReactionNotificationSource> &&notification_source);

  explicit ReactionNotificationsFrom(
      telegram_api::object_ptr<telegram_api::ReactionNotificationsFrom> &&notifications_from);

  td_api::object_ptr<td_api::ReactionNotificationSource> get_reaction_notification_source_object() const;

  telegram_api::object_ptr<telegram_api::ReactionNotificationsFrom> get_input_reaction_notifications_from() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const ReactionNotificationsFrom &lhs, const ReactionNotificationsFrom &rhs);

inline bool operator!=(const ReactionNotificationsFrom &lhs, const ReactionNotificationsFrom &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const ReactionNotificationsFrom &notifications_from);

}  // namespace td
