//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

namespace td {

struct MessageFullId {
 private:
  DialogId dialog_id;
  MessageId message_id;

 public:
  MessageFullId() : dialog_id(), message_id() {
  }

  MessageFullId(DialogId dialog_id, MessageId message_id) : dialog_id(dialog_id), message_id(message_id) {
  }

  bool operator==(const MessageFullId &other) const {
    return dialog_id == other.dialog_id && message_id == other.message_id;
  }

  bool operator!=(const MessageFullId &other) const {
    return !(*this == other);
  }

  DialogId get_dialog_id() const {
    return dialog_id;
  }

  MessageId get_message_id() const {
    return message_id;
  }

  static MessageFullId get_message_full_id(const tl_object_ptr<telegram_api::Message> &message_ptr, bool is_scheduled) {
    return get_message_full_id(message_ptr.get(), is_scheduled);
  }

  static MessageFullId get_message_full_id(const telegram_api::Message *message_ptr, bool is_scheduled) {
    return {DialogId::get_message_dialog_id(message_ptr), MessageId::get_message_id(message_ptr, is_scheduled)};
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    dialog_id.store(storer);
    message_id.store(storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    dialog_id.parse(parser);
    message_id.parse(parser);
  }
};

struct MessageFullIdHash {
  uint32 operator()(MessageFullId message_full_id) const {
    return combine_hashes(DialogIdHash()(message_full_id.get_dialog_id()),
                          MessageIdHash()(message_full_id.get_message_id()));
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, MessageFullId message_full_id) {
  return string_builder << message_full_id.get_message_id() << " in " << message_full_id.get_dialog_id();
}

}  // namespace td
