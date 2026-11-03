//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/MessageQuote.h"
#include "td/telegram/StoryFullId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Dependencies;

class Td;

class MessageInputReplyTo {
  MessageId message_id_;
  DialogId dialog_id_;
  MessageQuote quote_;
  // or
  StoryFullId story_full_id_;

  friend bool operator==(const MessageInputReplyTo &lhs, const MessageInputReplyTo &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const MessageInputReplyTo &input_reply_to);

  friend class RepliedMessageInfo;

 public:
  MessageInputReplyTo() = default;
  MessageInputReplyTo(const MessageInputReplyTo &) = delete;
  MessageInputReplyTo &operator=(const MessageInputReplyTo &) = delete;
  MessageInputReplyTo(MessageInputReplyTo &&) = default;
  MessageInputReplyTo &operator=(MessageInputReplyTo &&) = default;
  ~MessageInputReplyTo();

  MessageInputReplyTo(MessageId message_id, DialogId dialog_id, MessageQuote quote)
      : message_id_(message_id), dialog_id_(dialog_id), quote_(std::move(quote)) {
  }

  explicit MessageInputReplyTo(StoryFullId story_full_id) : story_full_id_(story_full_id) {
  }

  MessageInputReplyTo(Td *td, telegram_api::object_ptr<telegram_api::InputReplyTo> &&input_reply_to);

  bool is_empty() const {
    return !message_id_.is_valid() && !message_id_.is_valid_scheduled() && !story_full_id_.is_valid();
  }

  bool is_valid() const {
    return !is_empty();
  }

  bool has_quote() const {
    return !quote_.is_empty();
  }

  void set_quote(MessageQuote quote) {
    quote_ = std::move(quote);
  }

  StoryFullId get_story_full_id() const {
    return story_full_id_;
  }

  MessageInputReplyTo clone() const {
    if (story_full_id_.is_valid()) {
      return MessageInputReplyTo(story_full_id_);
    }
    return MessageInputReplyTo(message_id_, dialog_id_, quote_.clone());
  }

  void add_dependencies(Dependencies &dependencies) const;

  telegram_api::object_ptr<telegram_api::InputReplyTo> get_input_reply_to(Td *td,
                                                                          MessageId top_thread_message_id) const;

  td_api::object_ptr<td_api::InputMessageReplyTo> get_input_message_reply_to_object(Td *td) const;

  void set_message_id(MessageId new_message_id) {
    CHECK(message_id_.is_valid() || message_id_.is_valid_scheduled());
    message_id_ = new_message_id;
  }

  MessageId get_same_chat_reply_to_message_id() const;

  MessageFullId get_reply_message_full_id(DialogId owner_dialog_id) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const MessageInputReplyTo &lhs, const MessageInputReplyTo &rhs);

bool operator!=(const MessageInputReplyTo &lhs, const MessageInputReplyTo &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const MessageInputReplyTo &input_reply_to);

StringBuilder &operator<<(StringBuilder &string_builder, const MessageInputReplyTo *input_reply_to_ptr);

}  // namespace td
