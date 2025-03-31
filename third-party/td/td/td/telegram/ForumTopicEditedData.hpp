//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ForumTopicEditedData.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void ForumTopicEditedData::store(StorerT &storer) const {
  bool has_title = !title_.empty();
  bool has_icon_custom_emoji_id = icon_custom_emoji_id_.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(edit_icon_custom_emoji_id_);
  STORE_FLAG(edit_is_closed_);
  STORE_FLAG(is_closed_);
  STORE_FLAG(has_title);
  STORE_FLAG(has_icon_custom_emoji_id);
  STORE_FLAG(is_hidden_);
  END_STORE_FLAGS();
  if (has_title) {
    td::store(title_, storer);
  }
  if (has_icon_custom_emoji_id) {
    td::store(icon_custom_emoji_id_, storer);
  }
}

template <class ParserT>
void ForumTopicEditedData::parse(ParserT &parser) {
  bool has_title;
  bool has_icon_custom_emoji_id;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(edit_icon_custom_emoji_id_);
  PARSE_FLAG(edit_is_closed_);
  PARSE_FLAG(is_closed_);
  PARSE_FLAG(has_title);
  PARSE_FLAG(has_icon_custom_emoji_id);
  PARSE_FLAG(is_hidden_);
  END_PARSE_FLAGS();
  if (has_title) {
    td::parse(title_, parser);
  }
  if (has_icon_custom_emoji_id) {
    td::parse(icon_custom_emoji_id_, parser);
  }
}

}  // namespace td
