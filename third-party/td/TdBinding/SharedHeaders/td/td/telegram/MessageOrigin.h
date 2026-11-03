//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Dependencies;

class Td;

class MessageOrigin {
  UserId sender_user_id_;
  DialogId sender_dialog_id_;
  MessageId message_id_;
  string author_signature_;
  string sender_name_;

 public:
  MessageOrigin() = default;

  MessageOrigin(UserId sender_user_id, DialogId sender_dialog_id, MessageId message_id, string &&author_signature,
                string &&sender_name)
      : sender_user_id_(sender_user_id)
      , sender_dialog_id_(sender_dialog_id)
      , message_id_(message_id)
      , author_signature_(std::move(author_signature))
      , sender_name_(std::move(sender_name)) {
  }

  static Result<MessageOrigin> get_message_origin(
      Td *td, telegram_api::object_ptr<telegram_api::messageFwdHeader> &&forward_header);

  bool is_empty() const {
    return !sender_user_id_.is_valid() && !sender_dialog_id_.is_valid() && !message_id_.is_valid() &&
           author_signature_.empty() && sender_name_.empty();
  }

  td_api::object_ptr<td_api::MessageOrigin> get_message_origin_object(const Td *td) const;

  bool is_sender_hidden() const;

  MessageFullId get_message_full_id() const;

  const string &get_sender_name() const {
    return sender_name_;
  }

  bool is_channel_post() const {
    return message_id_.is_valid();
  }

  bool has_sender_signature() const {
    return !author_signature_.empty() || !sender_name_.empty();
  }

  DialogId get_sender() const;

  void hide_sender_if_needed(Td *td);

  void add_dependencies(Dependencies &dependencies) const;

  void add_user_ids(vector<UserId> &user_ids) const;

  void add_channel_ids(vector<ChannelId> &channel_ids) const;

  friend bool operator==(const MessageOrigin &lhs, const MessageOrigin &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const MessageOrigin &origin);

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const MessageOrigin &lhs, const MessageOrigin &rhs);

inline bool operator!=(const MessageOrigin &lhs, const MessageOrigin &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageOrigin &origin);

}  // namespace td
