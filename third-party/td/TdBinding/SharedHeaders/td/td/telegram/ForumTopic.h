//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/DialogNotificationSettings.h"
#include "td/telegram/DraftMessage.h"
#include "td/telegram/ForumTopicInfo.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"

namespace td {

class Td;

class ForumTopic {
  bool is_short_ = false;
  bool is_pinned_ = false;
  int32 unread_count_ = 0;
  MessageId last_message_id_;
  MessageId last_read_inbox_message_id_;
  MessageId last_read_outbox_message_id_;
  int32 unread_mention_count_ = 0;
  int32 unread_reaction_count_ = 0;
  DialogNotificationSettings notification_settings_;
  unique_ptr<DraftMessage> draft_message_;

 public:
  ForumTopic() = default;

  ForumTopic(Td *td, tl_object_ptr<telegram_api::ForumTopic> &&forum_topic_ptr,
             const DialogNotificationSettings *current_notification_settings);

  bool is_short() const {
    return is_short_;
  }

  bool update_last_read_outbox_message_id(MessageId last_read_outbox_message_id);

  bool update_last_read_inbox_message_id(MessageId last_read_inbox_message_id, int32 unread_count);

  bool set_is_pinned(bool is_pinned) {
    if (is_pinned_ == is_pinned) {
      return false;
    }
    is_pinned_ = is_pinned;
    return true;
  }

  DialogNotificationSettings *get_notification_settings() {
    return &notification_settings_;
  }

  const DialogNotificationSettings *get_notification_settings() const {
    return &notification_settings_;
  }

  td_api::object_ptr<td_api::forumTopic> get_forum_topic_object(Td *td, DialogId dialog_id,
                                                                const ForumTopicInfo &info) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

}  // namespace td
