//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/NotificationGroupId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

struct NotificationGroupKey {
  NotificationGroupId group_id;
  DialogId dialog_id;
  int32 last_notification_date = 0;

  NotificationGroupKey() = default;
  NotificationGroupKey(NotificationGroupId group_id, DialogId dialog_id, int32 last_notification_date)
      : group_id(group_id), dialog_id(dialog_id), last_notification_date(last_notification_date) {
  }

  bool operator<(const NotificationGroupKey &other) const {
    if (last_notification_date != other.last_notification_date) {
      return last_notification_date > other.last_notification_date;
    }
    if (dialog_id != other.dialog_id) {
      return dialog_id.get() > other.dialog_id.get();
    }
    return group_id.get() > other.group_id.get();
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, const NotificationGroupKey &group_key) {
  return string_builder << '[' << group_key.group_id << ',' << group_key.dialog_id << ','
                        << group_key.last_notification_date << ']';
}

}  // namespace td
