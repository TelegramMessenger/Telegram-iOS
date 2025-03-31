//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageOrigin.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void MessageOrigin::store(StorerT &storer) const {
  bool has_sender_user_id = sender_user_id_.is_valid();
  bool has_sender_dialog_id = sender_dialog_id_.is_valid();
  bool has_message_id = message_id_.is_valid();
  bool has_author_signature = !author_signature_.empty();
  bool has_sender_name = !sender_name_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_sender_user_id);
  STORE_FLAG(has_sender_dialog_id);
  STORE_FLAG(has_message_id);
  STORE_FLAG(has_author_signature);
  STORE_FLAG(has_sender_name);
  END_STORE_FLAGS();
  if (has_sender_user_id) {
    td::store(sender_user_id_, storer);
  }
  if (has_sender_dialog_id) {
    td::store(sender_dialog_id_, storer);
  }
  if (has_message_id) {
    td::store(message_id_, storer);
  }
  if (has_author_signature) {
    td::store(author_signature_, storer);
  }
  if (has_sender_name) {
    td::store(sender_name_, storer);
  }
}

template <class ParserT>
void MessageOrigin::parse(ParserT &parser) {
  bool has_sender_user_id;
  bool has_sender_dialog_id;
  bool has_message_id;
  bool has_author_signature;
  bool has_sender_name;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_sender_user_id);
  PARSE_FLAG(has_sender_dialog_id);
  PARSE_FLAG(has_message_id);
  PARSE_FLAG(has_author_signature);
  PARSE_FLAG(has_sender_name);
  END_PARSE_FLAGS();
  if (has_sender_user_id) {
    td::parse(sender_user_id_, parser);
  }
  if (has_sender_dialog_id) {
    td::parse(sender_dialog_id_, parser);
    CHECK(sender_dialog_id_.get_type() == DialogType::Channel);
  }
  if (has_message_id) {
    td::parse(message_id_, parser);
  }
  if (has_author_signature) {
    td::parse(author_signature_, parser);
  }
  if (has_sender_name) {
    td::parse(sender_name_, parser);
  }
}

}  // namespace td
