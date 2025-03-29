//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ForumTopicIcon.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void ForumTopicIcon::store(StorerT &storer) const {
  bool has_custom_emoji_id = custom_emoji_id_.is_valid();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_custom_emoji_id);
  END_STORE_FLAGS();
  td::store(color_, storer);
  if (has_custom_emoji_id) {
    td::store(custom_emoji_id_, storer);
  }
}

template <class ParserT>
void ForumTopicIcon::parse(ParserT &parser) {
  bool has_custom_emoji_id;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_custom_emoji_id);
  END_PARSE_FLAGS();
  td::parse(color_, parser);
  if (has_custom_emoji_id) {
    td::parse(custom_emoji_id_, parser);
  }
}

}  // namespace td
