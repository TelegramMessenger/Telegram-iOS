//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/StarGiftId.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void StarGiftId::store(StorerT &storer) const {
  CHECK(is_valid());
  bool has_server_message_id = server_message_id_.is_valid();
  bool has_dialog_id = dialog_id_.is_valid();
  bool has_saved_id = saved_id_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_server_message_id);
  STORE_FLAG(has_dialog_id);
  STORE_FLAG(has_saved_id);
  END_STORE_FLAGS();
  td::store(type_, storer);
  if (has_server_message_id) {
    td::store(server_message_id_, storer);
  }
  if (has_dialog_id) {
    td::store(dialog_id_, storer);
  }
  if (has_saved_id) {
    td::store(saved_id_, storer);
  }
}

template <class ParserT>
void StarGiftId::parse(ParserT &parser) {
  bool has_server_message_id;
  bool has_dialog_id;
  bool has_saved_id;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_server_message_id);
  PARSE_FLAG(has_dialog_id);
  PARSE_FLAG(has_saved_id);
  END_PARSE_FLAGS();
  td::parse(type_, parser);
  if (has_server_message_id) {
    td::parse(server_message_id_, parser);
  }
  if (has_dialog_id) {
    td::parse(dialog_id_, parser);
  }
  if (has_saved_id) {
    td::parse(saved_id_, parser);
  }
}

}  // namespace td
