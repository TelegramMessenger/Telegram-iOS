//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageReplyInfo.h"
#include "td/telegram/MinChannel.hpp"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void MessageReplyInfo::store(StorerT &storer) const {
  CHECK(!is_empty());
  bool has_recent_replier_dialog_ids = !recent_replier_dialog_ids_.empty();
  bool has_channel_id = channel_id_.is_valid();
  bool has_max_message_id = max_message_id_.is_valid();
  bool has_last_read_inbox_message_id = last_read_inbox_message_id_.is_valid();
  bool has_last_read_outbox_message_id = last_read_outbox_message_id_.is_valid();
  bool has_replier_min_channels = !replier_min_channels_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_comment_);
  STORE_FLAG(has_recent_replier_dialog_ids);
  STORE_FLAG(has_channel_id);
  STORE_FLAG(has_max_message_id);
  STORE_FLAG(has_last_read_inbox_message_id);
  STORE_FLAG(has_last_read_outbox_message_id);
  STORE_FLAG(has_replier_min_channels);
  END_STORE_FLAGS();
  td::store(reply_count_, storer);
  td::store(pts_, storer);
  if (has_recent_replier_dialog_ids) {
    td::store(recent_replier_dialog_ids_, storer);
  }
  if (has_channel_id) {
    td::store(channel_id_, storer);
  }
  if (has_max_message_id) {
    td::store(max_message_id_, storer);
  }
  if (has_last_read_inbox_message_id) {
    td::store(last_read_inbox_message_id_, storer);
  }
  if (has_last_read_outbox_message_id) {
    td::store(last_read_outbox_message_id_, storer);
  }
  if (has_replier_min_channels) {
    td::store(replier_min_channels_, storer);
  }
}

template <class ParserT>
void MessageReplyInfo::parse(ParserT &parser) {
  bool has_recent_replier_dialog_ids;
  bool has_channel_id;
  bool has_max_message_id;
  bool has_last_read_inbox_message_id;
  bool has_last_read_outbox_message_id;
  bool has_replier_min_channels;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_comment_);
  PARSE_FLAG(has_recent_replier_dialog_ids);
  PARSE_FLAG(has_channel_id);
  PARSE_FLAG(has_max_message_id);
  PARSE_FLAG(has_last_read_inbox_message_id);
  PARSE_FLAG(has_last_read_outbox_message_id);
  PARSE_FLAG(has_replier_min_channels);
  END_PARSE_FLAGS();
  td::parse(reply_count_, parser);
  td::parse(pts_, parser);
  if (has_recent_replier_dialog_ids) {
    td::parse(recent_replier_dialog_ids_, parser);
  }
  if (has_channel_id) {
    td::parse(channel_id_, parser);
  }
  if (has_max_message_id) {
    td::parse(max_message_id_, parser);
  }
  if (has_last_read_inbox_message_id) {
    td::parse(last_read_inbox_message_id_, parser);
  }
  if (has_last_read_outbox_message_id) {
    td::parse(last_read_outbox_message_id_, parser);
  }
  if (has_replier_min_channels) {
    td::parse(replier_min_channels_, parser);
  }

  if (channel_id_.get() == 777) {
    *this = MessageReplyInfo();
    is_dropped_ = true;
  }
  if (recent_replier_dialog_ids_.size() > MAX_RECENT_REPLIERS) {
    recent_replier_dialog_ids_.resize(MAX_RECENT_REPLIERS);
  }
}

}  // namespace td
