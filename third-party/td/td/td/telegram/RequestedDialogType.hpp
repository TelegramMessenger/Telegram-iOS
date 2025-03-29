//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/RequestedDialogType.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void RequestedDialogType::store(StorerT &storer) const {
  bool has_max_quantity = max_quantity_ != 1;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(restrict_is_bot_);
  STORE_FLAG(is_bot_);
  STORE_FLAG(restrict_is_premium_);
  STORE_FLAG(is_premium_);
  STORE_FLAG(restrict_is_forum_);
  STORE_FLAG(is_forum_);
  STORE_FLAG(bot_is_participant_);
  STORE_FLAG(restrict_has_username_);
  STORE_FLAG(has_username_);
  STORE_FLAG(is_created_);
  STORE_FLAG(restrict_user_administrator_rights_);
  STORE_FLAG(restrict_bot_administrator_rights_);
  STORE_FLAG(has_max_quantity);
  END_STORE_FLAGS();
  td::store(type_, storer);
  td::store(button_id_, storer);
  if (restrict_user_administrator_rights_) {
    td::store(user_administrator_rights_, storer);
  }
  if (restrict_bot_administrator_rights_) {
    td::store(bot_administrator_rights_, storer);
  }
  if (has_max_quantity) {
    td::store(max_quantity_, storer);
  }
}

template <class ParserT>
void RequestedDialogType::parse(ParserT &parser) {
  bool has_max_quantity;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(restrict_is_bot_);
  PARSE_FLAG(is_bot_);
  PARSE_FLAG(restrict_is_premium_);
  PARSE_FLAG(is_premium_);
  PARSE_FLAG(restrict_is_forum_);
  PARSE_FLAG(is_forum_);
  PARSE_FLAG(bot_is_participant_);
  PARSE_FLAG(restrict_has_username_);
  PARSE_FLAG(has_username_);
  PARSE_FLAG(is_created_);
  PARSE_FLAG(restrict_user_administrator_rights_);
  PARSE_FLAG(restrict_bot_administrator_rights_);
  PARSE_FLAG(has_max_quantity);
  END_PARSE_FLAGS();
  td::parse(type_, parser);
  td::parse(button_id_, parser);
  if (restrict_user_administrator_rights_) {
    td::parse(user_administrator_rights_, parser);
  }
  if (restrict_bot_administrator_rights_) {
    td::parse(bot_administrator_rights_, parser);
  }
  if (has_max_quantity) {
    td::parse(max_quantity_, parser);
  } else {
    max_quantity_ = 1;
  }
}

}  // namespace td
