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

enum class NotificationSettingsScope : int32 { Private, Group, Channel };

StringBuilder &operator<<(StringBuilder &string_builder, NotificationSettingsScope scope);

td_api::object_ptr<td_api::NotificationSettingsScope> get_notification_settings_scope_object(
    NotificationSettingsScope scope);

telegram_api::object_ptr<telegram_api::InputNotifyPeer> get_input_notify_peer(NotificationSettingsScope scope);

NotificationSettingsScope get_notification_settings_scope(
    const td_api::object_ptr<td_api::NotificationSettingsScope> &scope);

}  // namespace td
