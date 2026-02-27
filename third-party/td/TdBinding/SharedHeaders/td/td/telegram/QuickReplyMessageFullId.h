//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageId.h"
#include "td/telegram/QuickReplyShortcutId.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

namespace td {

struct QuickReplyMessageFullId {
 private:
  QuickReplyShortcutId quick_reply_shortcut_id;
  MessageId message_id;

 public:
  QuickReplyMessageFullId() = default;

  QuickReplyMessageFullId(QuickReplyShortcutId quick_reply_shortcut_id, MessageId message_id)
      : quick_reply_shortcut_id(quick_reply_shortcut_id), message_id(message_id) {
  }

  bool operator==(const QuickReplyMessageFullId &other) const {
    return quick_reply_shortcut_id == other.quick_reply_shortcut_id && message_id == other.message_id;
  }

  bool operator!=(const QuickReplyMessageFullId &other) const {
    return !(*this == other);
  }

  QuickReplyShortcutId get_quick_reply_shortcut_id() const {
    return quick_reply_shortcut_id;
  }

  MessageId get_message_id() const {
    return message_id;
  }

  bool is_valid() const {
    return quick_reply_shortcut_id.is_valid() && message_id.is_valid();
  }

  bool is_server() const {
    return quick_reply_shortcut_id.is_valid() && message_id.is_server();
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    quick_reply_shortcut_id.store(storer);
    message_id.store(storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    quick_reply_shortcut_id.parse(parser);
    message_id.parse(parser);
  }
};

struct QuickReplyMessageFullIdHash {
  uint32 operator()(QuickReplyMessageFullId quick_reply_message_full_id) const {
    return combine_hashes(QuickReplyShortcutIdHash()(quick_reply_message_full_id.get_quick_reply_shortcut_id()),
                          MessageIdHash()(quick_reply_message_full_id.get_message_id()));
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, QuickReplyMessageFullId quick_reply_message_full_id) {
  return string_builder << quick_reply_message_full_id.get_message_id() << " from "
                        << quick_reply_message_full_id.get_quick_reply_shortcut_id();
}

}  // namespace td
