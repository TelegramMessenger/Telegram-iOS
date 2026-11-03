//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageEntity.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageInputReplyTo.h"
#include "td/telegram/ReplyMarkup.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

struct MessageCopyOptions {
  bool send_copy = false;
  bool replace_caption = false;
  bool new_invert_media = false;
  FormattedText new_caption;
  MessageInputReplyTo input_reply_to;
  unique_ptr<ReplyMarkup> reply_markup;

  MessageCopyOptions() = default;
  MessageCopyOptions(bool send_copy, bool remove_caption) : send_copy(send_copy), replace_caption(remove_caption) {
  }

  bool is_supported_server_side(MessageId top_thread_message_id) const {
    if (!send_copy) {
      return true;
    }
    if ((replace_caption && !new_caption.text.empty()) || reply_markup != nullptr) {
      return false;
    }
    if (input_reply_to.is_valid() && (top_thread_message_id == MessageId() || input_reply_to.has_quote() ||
                                      input_reply_to.get_same_chat_reply_to_message_id() != top_thread_message_id)) {
      return false;
    }
    return true;
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, MessageCopyOptions copy_options) {
  if (copy_options.send_copy) {
    string_builder << "CopyOptions[replace_caption = " << copy_options.replace_caption;
    if (copy_options.replace_caption) {
      string_builder << ", new_caption = " << copy_options.new_caption
                     << ", new_show_caption_above_media = " << copy_options.new_invert_media;
    }
    if (copy_options.input_reply_to.is_valid()) {
      string_builder << ", in reply to " << copy_options.input_reply_to;
    }
    if (copy_options.reply_markup != nullptr) {
      string_builder << ", with reply markup";
    }
    string_builder << "]";
  }
  return string_builder;
}

}  // namespace td
