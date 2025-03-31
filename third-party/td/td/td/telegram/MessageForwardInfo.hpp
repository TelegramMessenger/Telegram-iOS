//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageForwardInfo.h"
#include "td/telegram/MessageOrigin.hpp"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void LastForwardedMessageInfo::store(StorerT &storer) const {
  bool has_sender_dialog_id = sender_dialog_id_.is_valid();
  bool has_sender_name = !sender_name_.empty();
  bool has_date = date_ > 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_sender_dialog_id);
  STORE_FLAG(has_sender_name);
  STORE_FLAG(has_date);
  STORE_FLAG(is_outgoing_);
  END_STORE_FLAGS();
  td::store(dialog_id_, storer);
  td::store(message_id_, storer);
  if (has_sender_dialog_id) {
    td::store(sender_dialog_id_, storer);
  }
  if (has_sender_name) {
    td::store(sender_name_, storer);
  }
  if (has_date) {
    td::store(date_, storer);
  }
}

template <class ParserT>
void LastForwardedMessageInfo::parse(ParserT &parser) {
  bool has_sender_dialog_id;
  bool has_sender_name;
  bool has_date;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_sender_dialog_id);
  PARSE_FLAG(has_sender_name);
  PARSE_FLAG(has_date);
  PARSE_FLAG(is_outgoing_);
  END_PARSE_FLAGS();
  td::parse(dialog_id_, parser);
  td::parse(message_id_, parser);
  if (has_sender_dialog_id) {
    td::parse(sender_dialog_id_, parser);
  }
  if (has_sender_name) {
    td::parse(sender_name_, parser);
  }
  if (has_date) {
    td::parse(date_, parser);
  }

  validate();
}

template <class StorerT>
void MessageForwardInfo::store(StorerT &storer) const {
  bool has_last_message_info = !last_message_info_.is_empty();
  bool has_psa_type = !psa_type_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_imported_);
  STORE_FLAG(has_last_message_info);
  STORE_FLAG(has_psa_type);
  END_STORE_FLAGS();
  td::store(origin_, storer);
  td::store(date_, storer);
  if (has_last_message_info) {
    td::store(last_message_info_, storer);
  }
  if (has_psa_type) {
    td::store(psa_type_, storer);
  }
}

template <class ParserT>
void MessageForwardInfo::parse(ParserT &parser) {
  bool has_last_message_info;
  bool has_psa_type;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_imported_);
  PARSE_FLAG(has_last_message_info);
  PARSE_FLAG(has_psa_type);
  END_PARSE_FLAGS();
  td::parse(origin_, parser);
  td::parse(date_, parser);
  if (has_last_message_info) {
    td::parse(last_message_info_, parser);
  }
  if (has_psa_type) {
    td::parse(psa_type_, parser);
  }
}

}  // namespace td
