//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/CallId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/Document.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/NotificationObjectId.h"
#include "td/telegram/Photo.h"
#include "td/telegram/td_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class NotificationType {
 public:
  NotificationType() = default;
  NotificationType(const NotificationType &) = delete;
  NotificationType &operator=(const NotificationType &) = delete;
  NotificationType(NotificationType &&) = delete;
  NotificationType &operator=(NotificationType &&) = delete;
  virtual ~NotificationType() = default;

  virtual bool can_be_delayed() const = 0;

  virtual bool is_temporary() const = 0;

  virtual NotificationObjectId get_object_id() const = 0;

  virtual vector<FileId> get_file_ids(const Td *td) const = 0;

  virtual td_api::object_ptr<td_api::NotificationType> get_notification_type_object(Td *td,
                                                                                    DialogId dialog_id) const = 0;

  virtual StringBuilder &to_string_builder(StringBuilder &string_builder) const = 0;
};

inline StringBuilder &operator<<(StringBuilder &string_builder, const NotificationType &notification_type) {
  return notification_type.to_string_builder(string_builder);
}

inline StringBuilder &operator<<(StringBuilder &string_builder, const unique_ptr<NotificationType> &notification_type) {
  if (notification_type == nullptr) {
    return string_builder << "null";
  }
  return string_builder << *notification_type;
}

unique_ptr<NotificationType> create_new_message_notification(MessageId message_id, bool show_preview);

unique_ptr<NotificationType> create_new_secret_chat_notification();

unique_ptr<NotificationType> create_new_call_notification(CallId call_id);

unique_ptr<NotificationType> create_new_push_message_notification(UserId sender_user_id, DialogId sender_dialog_id,
                                                                  string sender_name, bool is_outgoing,
                                                                  MessageId message_id, string key, string arg,
                                                                  Photo photo, Document document);

}  // namespace td
