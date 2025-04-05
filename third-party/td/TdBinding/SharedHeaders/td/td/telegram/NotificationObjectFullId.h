//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/NotificationObjectId.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

namespace td {

struct NotificationObjectFullId {
 private:
  DialogId dialog_id;
  NotificationObjectId notification_object_id;

 public:
  NotificationObjectFullId() : dialog_id(), notification_object_id() {
  }

  NotificationObjectFullId(DialogId dialog_id, NotificationObjectId notification_object_id)
      : dialog_id(dialog_id), notification_object_id(notification_object_id) {
  }

  bool operator==(const NotificationObjectFullId &other) const {
    return dialog_id == other.dialog_id && notification_object_id == other.notification_object_id;
  }

  bool operator!=(const NotificationObjectFullId &other) const {
    return !(*this == other);
  }

  DialogId get_dialog_id() const {
    return dialog_id;
  }

  NotificationObjectId get_notification_object_id() const {
    return notification_object_id;
  }
};

struct NotificationObjectFullIdHash {
  uint32 operator()(NotificationObjectFullId full_notification_object_id) const {
    return combine_hashes(DialogIdHash()(full_notification_object_id.get_dialog_id()),
                          NotificationObjectIdHash()(full_notification_object_id.get_notification_object_id()));
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, NotificationObjectFullId full_notification_object_id) {
  return string_builder << full_notification_object_id.get_notification_object_id() << " in "
                        << full_notification_object_id.get_dialog_id();
}

}  // namespace td
