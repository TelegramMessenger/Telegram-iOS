//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ForumTopicInfo.h"

#include "td/telegram/ForumTopicIcon.hpp"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void ForumTopicInfo::store(StorerT &storer) const {
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_outgoing_);
  STORE_FLAG(is_closed_);
  STORE_FLAG(is_hidden_);
  END_STORE_FLAGS();
  td::store(top_thread_message_id_, storer);
  td::store(title_, storer);
  td::store(icon_, storer);
  td::store(creation_date_, storer);
  td::store(creator_dialog_id_, storer);
}

template <class ParserT>
void ForumTopicInfo::parse(ParserT &parser) {
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_outgoing_);
  PARSE_FLAG(is_closed_);
  PARSE_FLAG(is_hidden_);
  END_PARSE_FLAGS();
  td::parse(top_thread_message_id_, parser);
  td::parse(title_, parser);
  td::parse(icon_, parser);
  td::parse(creation_date_, parser);
  td::parse(creator_dialog_id_, parser);
}

}  // namespace td
