//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Photo.hpp"
#include "td/telegram/SharedDialog.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void SharedDialog::store(StorerT &storer) const {
  bool has_first_name = !first_name_.empty();
  bool has_last_name = !last_name_.empty();
  bool has_username = !username_.empty();
  bool has_photo = !photo_.is_empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_first_name);
  STORE_FLAG(has_last_name);
  STORE_FLAG(has_username);
  STORE_FLAG(has_photo);
  END_STORE_FLAGS();
  td::store(dialog_id_, storer);
  if (has_first_name) {
    td::store(first_name_, storer);
  }
  if (has_last_name) {
    td::store(last_name_, storer);
  }
  if (has_username) {
    td::store(username_, storer);
  }
  if (has_photo) {
    td::store(photo_, storer);
  }
}

template <class ParserT>
void SharedDialog::parse(ParserT &parser) {
  bool has_first_name;
  bool has_last_name;
  bool has_username;
  bool has_photo;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_first_name);
  PARSE_FLAG(has_last_name);
  PARSE_FLAG(has_username);
  PARSE_FLAG(has_photo);
  END_PARSE_FLAGS();
  td::parse(dialog_id_, parser);
  if (has_first_name) {
    td::parse(first_name_, parser);
  }
  if (has_last_name) {
    td::parse(last_name_, parser);
  }
  if (has_username) {
    td::parse(username_, parser);
  }
  if (has_photo) {
    td::parse(photo_, parser);
  }
}

}  // namespace td
