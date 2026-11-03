//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/Notification.h"
#include "td/telegram/NotificationGroupType.h"

#include "td/utils/common.h"

namespace td {

struct NotificationGroupFromDatabase {
  DialogId dialog_id;
  NotificationGroupType type = NotificationGroupType::Calls;
  int32 total_count = 0;
  vector<Notification> notifications;
};

}  // namespace td
