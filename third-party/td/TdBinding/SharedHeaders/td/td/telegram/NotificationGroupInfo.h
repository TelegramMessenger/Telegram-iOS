//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/NotificationGroupId.h"
#include "td/telegram/NotificationGroupKey.h"
#include "td/telegram/NotificationId.h"
#include "td/telegram/NotificationObjectId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class NotificationGroupInfo {
  NotificationGroupId group_id_;
  int32 last_notification_date_ = 0;            // date of the last notification in the group
  NotificationId last_notification_id_;         // identifier of the last notification in the group
  NotificationId max_removed_notification_id_;  // notification identifier, up to which all notifications are removed
  NotificationObjectId max_removed_object_id_;  // object identifier, up to which all notifications are removed
  bool is_key_changed_ = false;                 // true, if the group needs to be saved to database
  bool try_reuse_ = false;  // true, if the group needs to be deleted from database and tried to be reused

  friend StringBuilder &operator<<(StringBuilder &string_builder, const NotificationGroupInfo &group_info);

 public:
  NotificationGroupInfo() = default;

  explicit NotificationGroupInfo(NotificationGroupId group_id) : group_id_(group_id), is_key_changed_(true) {
  }

  bool is_valid() const {
    return group_id_.is_valid();
  }

  bool is_active() const {
    return is_valid() && !try_reuse_;
  }

  NotificationGroupId get_group_id() const {
    return group_id_;
  }

  bool has_group_id(NotificationGroupId group_id) const {
    return group_id_ == group_id;
  }

  NotificationId get_last_notification_id() const {
    return last_notification_id_;
  }

  bool set_last_notification(int32 last_notification_date, NotificationId last_notification_id, const char *source);

  bool set_max_removed_notification_id(NotificationId max_removed_notification_id,
                                       NotificationObjectId max_removed_object_id, const char *source);

  void drop_max_removed_notification_id();

  bool is_removed_notification(NotificationId notification_id, NotificationObjectId object_id) const;

  bool is_removed_notification_id(NotificationId notification_id) const;

  bool is_removed_object_id(NotificationObjectId object_id) const;

  bool is_used_notification_id(NotificationId notification_id) const;

  void try_reuse();

  void add_group_key_if_changed(vector<NotificationGroupKey> &group_keys, DialogId dialog_id);

  NotificationGroupId get_reused_group_id();

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

StringBuilder &operator<<(StringBuilder &string_builder, const NotificationGroupInfo &group_info);

}  // namespace td
