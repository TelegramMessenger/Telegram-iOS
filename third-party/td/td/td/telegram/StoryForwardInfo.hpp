//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/StoryForwardInfo.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void StoryForwardInfo::store(StorerT &storer) const {
  using td::store;
  bool has_dialog_id = dialog_id_.is_valid();
  bool has_story_id = story_id_.is_valid();
  bool has_sender_name = !sender_name_.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_dialog_id);
  STORE_FLAG(has_story_id);
  STORE_FLAG(has_sender_name);
  STORE_FLAG(is_modified_);
  END_STORE_FLAGS();
  if (has_dialog_id) {
    store(dialog_id_, storer);
  }
  if (has_story_id) {
    store(story_id_, storer);
  }
  if (has_sender_name) {
    store(sender_name_, storer);
  }
}

template <class ParserT>
void StoryForwardInfo::parse(ParserT &parser) {
  using td::parse;
  bool has_dialog_id;
  bool has_story_id;
  bool has_sender_name;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_dialog_id);
  PARSE_FLAG(has_story_id);
  PARSE_FLAG(has_sender_name);
  PARSE_FLAG(is_modified_);
  END_PARSE_FLAGS();
  if (has_dialog_id) {
    parse(dialog_id_, parser);
  }
  if (has_story_id) {
    parse(story_id_, parser);
  }
  if (has_sender_name) {
    parse(sender_name_, parser);
  }
}

}  // namespace td
