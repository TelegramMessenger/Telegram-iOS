//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogNotificationSettings.hpp"
#include "td/telegram/DraftMessage.hpp"
#include "td/telegram/ForumTopic.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void ForumTopic::store(StorerT &storer) const {
  bool has_unread_count = unread_count_ != 0;
  bool has_last_message_id = last_message_id_.is_valid();
  bool has_last_read_inbox_message_id = last_read_inbox_message_id_.is_valid();
  bool has_last_read_outbox_message_id = last_read_outbox_message_id_.is_valid();
  bool has_unread_mention_count = unread_mention_count_ != 0;
  bool has_unread_reaction_count = unread_reaction_count_ != 0;
  bool has_draft_message = draft_message_ != nullptr;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_short_);
  STORE_FLAG(is_pinned_);
  STORE_FLAG(has_unread_count);
  STORE_FLAG(has_last_message_id);
  STORE_FLAG(has_last_read_inbox_message_id);
  STORE_FLAG(has_last_read_outbox_message_id);
  STORE_FLAG(has_unread_mention_count);
  STORE_FLAG(has_unread_reaction_count);
  STORE_FLAG(has_draft_message);
  END_STORE_FLAGS();
  if (has_unread_count) {
    td::store(unread_count_, storer);
  }
  if (has_last_message_id) {
    td::store(last_message_id_, storer);
  }
  if (has_last_read_inbox_message_id) {
    td::store(last_read_inbox_message_id_, storer);
  }
  if (has_last_read_outbox_message_id) {
    td::store(last_read_outbox_message_id_, storer);
  }
  if (has_unread_mention_count) {
    td::store(unread_mention_count_, storer);
  }
  if (has_unread_reaction_count) {
    td::store(unread_reaction_count_, storer);
  }
  td::store(notification_settings_, storer);
  if (has_draft_message) {
    td::store(draft_message_, storer);
  }
}

template <class ParserT>
void ForumTopic::parse(ParserT &parser) {
  bool has_unread_count;
  bool has_last_message_id;
  bool has_last_read_inbox_message_id;
  bool has_last_read_outbox_message_id;
  bool has_unread_mention_count;
  bool has_unread_reaction_count;
  bool has_draft_message;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_short_);
  PARSE_FLAG(is_pinned_);
  PARSE_FLAG(has_unread_count);
  PARSE_FLAG(has_last_message_id);
  PARSE_FLAG(has_last_read_inbox_message_id);
  PARSE_FLAG(has_last_read_outbox_message_id);
  PARSE_FLAG(has_unread_mention_count);
  PARSE_FLAG(has_unread_reaction_count);
  PARSE_FLAG(has_draft_message);
  END_PARSE_FLAGS();
  if (has_unread_count) {
    td::parse(unread_count_, parser);
  }
  if (has_last_message_id) {
    td::parse(last_message_id_, parser);
  }
  if (has_last_read_inbox_message_id) {
    td::parse(last_read_inbox_message_id_, parser);
  }
  if (has_last_read_outbox_message_id) {
    td::parse(last_read_outbox_message_id_, parser);
  }
  if (has_unread_mention_count) {
    td::parse(unread_mention_count_, parser);
  }
  if (has_unread_reaction_count) {
    td::parse(unread_reaction_count_, parser);
  }
  td::parse(notification_settings_, parser);
  if (has_draft_message) {
    td::parse(draft_message_, parser);
  }
}

}  // namespace td
