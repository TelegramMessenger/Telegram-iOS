//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/NotificationGroupInfo.h"

#include "td/telegram/NotificationManager.h"

#include "td/utils/logging.h"

namespace td {

bool NotificationGroupInfo::set_last_notification(int32 last_notification_date, NotificationId last_notification_id,
                                                  const char *source) {
  if (is_removed_notification_id(last_notification_id)) {
    last_notification_id = NotificationId();
    last_notification_date = 0;
  }
  if (last_notification_date_ != last_notification_date || last_notification_id_ != last_notification_id) {
    VLOG(notifications) << "Set " << group_id_ << " last notification to " << last_notification_id << " sent at "
                        << last_notification_date << " from " << source;
    if (last_notification_date_ != last_notification_date) {
      last_notification_date_ = last_notification_date;
      is_key_changed_ = true;
    }
    last_notification_id_ = last_notification_id;
    return true;
  }
  return false;
}

bool NotificationGroupInfo::set_max_removed_notification_id(NotificationId max_removed_notification_id,
                                                            NotificationObjectId max_removed_object_id,
                                                            const char *source) {
  if (max_removed_notification_id.get() <= max_removed_notification_id_.get()) {
    return false;
  }
  if (max_removed_object_id > max_removed_object_id_) {
    VLOG(notifications) << "Set max_removed_object_id in " << group_id_ << " to " << max_removed_object_id << " from "
                        << source;
    max_removed_object_id_ = max_removed_object_id;
  }

  VLOG(notifications) << "Set max_removed_notification_id in " << group_id_ << " to " << max_removed_notification_id
                      << " from " << source;
  max_removed_notification_id_ = max_removed_notification_id;

  if (last_notification_id_.is_valid() && is_removed_notification_id(last_notification_id_)) {
    last_notification_id_ = NotificationId();
    last_notification_date_ = 0;
    is_key_changed_ = true;
  }

  return true;
}

void NotificationGroupInfo::drop_max_removed_notification_id() {
  if (!max_removed_notification_id_.is_valid()) {
    return;
  }

  VLOG(notifications) << "Drop max_removed_notification_id in " << group_id_;
  max_removed_object_id_ = {};
  max_removed_notification_id_ = NotificationId();
}

bool NotificationGroupInfo::is_removed_notification(NotificationId notification_id,
                                                    NotificationObjectId object_id) const {
  return is_removed_notification_id(notification_id) || is_removed_object_id(object_id);
}

bool NotificationGroupInfo::is_removed_notification_id(NotificationId notification_id) const {
  return notification_id.get() <= max_removed_notification_id_.get();
}

bool NotificationGroupInfo::is_removed_object_id(NotificationObjectId object_id) const {
  return object_id <= max_removed_object_id_;
}

bool NotificationGroupInfo::is_used_notification_id(NotificationId notification_id) const {
  return notification_id.get() <= max_removed_notification_id_.get() ||
         notification_id.get() <= last_notification_id_.get();
}

void NotificationGroupInfo::try_reuse() {
  CHECK(is_valid());
  CHECK(last_notification_date_ == 0);
  if (!try_reuse_) {
    try_reuse_ = true;
    is_key_changed_ = true;
  }
}

void NotificationGroupInfo::add_group_key_if_changed(vector<NotificationGroupKey> &group_keys, DialogId dialog_id) {
  if (!is_key_changed_) {
    return;
  }
  is_key_changed_ = false;

  group_keys.emplace_back(group_id_, try_reuse_ ? DialogId() : dialog_id, last_notification_date_);
}

NotificationGroupId NotificationGroupInfo::get_reused_group_id() {
  if (!try_reuse_) {
    return {};
  }
  if (is_key_changed_) {
    LOG(ERROR) << "Failed to reuse changed " << group_id_;
    return {};
  }
  try_reuse_ = false;
  if (!is_valid()) {
    LOG(ERROR) << "Failed to reuse invalid " << group_id_;
    return {};
  }
  CHECK(last_notification_id_ == NotificationId());
  CHECK(last_notification_date_ == 0);
  auto result = group_id_;
  group_id_ = NotificationGroupId();
  max_removed_notification_id_ = NotificationId();
  max_removed_object_id_ = {};
  return result;
}

StringBuilder &operator<<(StringBuilder &string_builder, const NotificationGroupInfo &group_info) {
  return string_builder << group_info.group_id_ << " with last " << group_info.last_notification_id_ << " sent at "
                        << group_info.last_notification_date_ << ", max removed "
                        << group_info.max_removed_notification_id_ << '/' << group_info.max_removed_object_id_;
}

}  // namespace td
