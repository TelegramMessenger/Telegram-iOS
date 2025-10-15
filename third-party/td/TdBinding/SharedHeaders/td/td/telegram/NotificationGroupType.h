//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

enum class NotificationGroupType : int8 { Messages, Mentions, SecretChat, Calls };

bool is_database_notification_group_type(NotificationGroupType type);

bool is_partial_notification_group_type(NotificationGroupType type);

td_api::object_ptr<td_api::NotificationGroupType> get_notification_group_type_object(NotificationGroupType type);

NotificationGroupType get_notification_group_type(const td_api::object_ptr<td_api::NotificationGroupType> &type);

StringBuilder &operator<<(StringBuilder &string_builder, const NotificationGroupType &type);

}  // namespace td
