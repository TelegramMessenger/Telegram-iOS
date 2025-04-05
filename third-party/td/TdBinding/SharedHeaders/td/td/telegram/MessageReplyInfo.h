//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MinChannel.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

#include <utility>

namespace td {

class Td;

struct MessageReplyInfo {
  int32 reply_count_ = -1;
  int32 pts_ = -1;
  vector<DialogId> recent_replier_dialog_ids_;                     // comments only
  vector<std::pair<ChannelId, MinChannel>> replier_min_channels_;  // comments only
  ChannelId channel_id_;                                           // comments only
  MessageId max_message_id_;
  MessageId last_read_inbox_message_id_;
  MessageId last_read_outbox_message_id_;
  bool is_comment_ = false;
  bool is_dropped_ = false;

  static constexpr size_t MAX_RECENT_REPLIERS = 3;

  MessageReplyInfo() = default;

  MessageReplyInfo(Td *td, tl_object_ptr<telegram_api::messageReplies> &&reply_info, bool is_bot);

  bool is_empty() const {
    return reply_count_ < 0;
  }

  bool was_dropped() const {
    return is_dropped_;
  }

  bool need_update_to(const MessageReplyInfo &other) const;

  bool update_max_message_ids(MessageId other_max_message_id, MessageId other_last_read_inbox_message_id,
                              MessageId other_last_read_outbox_message_id);

  bool update_max_message_ids(const MessageReplyInfo &other);

  bool add_reply(DialogId replier_dialog_id, MessageId reply_message_id, int diff);

  bool need_reget(const Td *td) const;

  td_api::object_ptr<td_api::messageReplyInfo> get_message_reply_info_object(
      Td *td, MessageId dialog_last_read_inbox_message_id) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

StringBuilder &operator<<(StringBuilder &string_builder, const MessageReplyInfo &reply_info);

}  // namespace td
