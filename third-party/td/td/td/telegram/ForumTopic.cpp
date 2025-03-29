//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/ForumTopic.h"

#include "td/telegram/DraftMessage.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/Td.h"

#include "td/utils/logging.h"

namespace td {

ForumTopic::ForumTopic(Td *td, tl_object_ptr<telegram_api::ForumTopic> &&forum_topic_ptr,
                       const DialogNotificationSettings *current_notification_settings) {
  CHECK(forum_topic_ptr != nullptr);
  if (forum_topic_ptr->get_id() != telegram_api::forumTopic::ID) {
    LOG(INFO) << "Receive " << to_string(forum_topic_ptr);
    return;
  }

  auto *forum_topic = static_cast<telegram_api::forumTopic *>(forum_topic_ptr.get());
  is_short_ = forum_topic->short_;
  is_pinned_ = forum_topic->pinned_;
  notification_settings_ =
      get_dialog_notification_settings(std::move(forum_topic->notify_settings_), current_notification_settings);
  draft_message_ = get_draft_message(td, std::move(forum_topic->draft_));

  if (is_short_) {
    return;
  }

  last_message_id_ = MessageId(ServerMessageId(forum_topic->top_message_));
  unread_count_ = forum_topic->unread_count_;
  last_read_inbox_message_id_ = MessageId(ServerMessageId(forum_topic->read_inbox_max_id_));
  last_read_outbox_message_id_ = MessageId(ServerMessageId(forum_topic->read_outbox_max_id_));
  unread_mention_count_ = forum_topic->unread_mentions_count_;
  unread_reaction_count_ = forum_topic->unread_reactions_count_;
}

bool ForumTopic::update_last_read_outbox_message_id(MessageId last_read_outbox_message_id) {
  if (last_read_outbox_message_id <= last_read_outbox_message_id_) {
    return false;
  }
  last_read_outbox_message_id_ = last_read_outbox_message_id;
  return true;
}

bool ForumTopic::update_last_read_inbox_message_id(MessageId last_read_inbox_message_id, int32 unread_count) {
  if (last_read_inbox_message_id <= last_read_inbox_message_id_) {
    return false;
  }
  last_read_inbox_message_id_ = last_read_inbox_message_id;
  if (unread_count >= 0) {
    unread_count_ = unread_count;
  }
  return true;
}

td_api::object_ptr<td_api::forumTopic> ForumTopic::get_forum_topic_object(Td *td, DialogId dialog_id,
                                                                          const ForumTopicInfo &info) const {
  if (info.is_empty()) {
    return nullptr;
  }

  // TODO draft_message = can_send_message(dialog_id, info_.get_top_thread_message_id()).is_ok() ? ... : nullptr;
  auto last_message =
      td->messages_manager_->get_message_object({dialog_id, last_message_id_}, "get_forum_topic_object");
  auto draft_message = get_draft_message_object(td, draft_message_);
  return td_api::make_object<td_api::forumTopic>(
      info.get_forum_topic_info_object(td), std::move(last_message), is_pinned_, unread_count_,
      last_read_inbox_message_id_.get(), last_read_outbox_message_id_.get(), unread_mention_count_,
      unread_reaction_count_, get_chat_notification_settings_object(&notification_settings_), std::move(draft_message));
}

}  // namespace td
