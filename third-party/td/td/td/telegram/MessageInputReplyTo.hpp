//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageInputReplyTo.h"

#include "td/telegram/MessageOrigin.hpp"
#include "td/telegram/MessageQuote.h"
#include "td/telegram/MessageQuote.hpp"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void MessageInputReplyTo::store(StorerT &storer) const {
  bool has_message_id = message_id_.is_valid();
  bool has_story_full_id = story_full_id_.is_valid();
  bool has_dialog_id = dialog_id_.is_valid();
  bool has_quote = !quote_.is_empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_message_id);
  STORE_FLAG(has_story_full_id);
  STORE_FLAG(false);
  STORE_FLAG(has_dialog_id);
  STORE_FLAG(false);
  STORE_FLAG(has_quote);
  END_STORE_FLAGS();
  if (has_message_id) {
    td::store(message_id_, storer);
  }
  if (has_story_full_id) {
    td::store(story_full_id_, storer);
  }
  if (has_dialog_id) {
    td::store(dialog_id_, storer);
  }
  if (has_quote) {
    td::store(quote_, storer);
  }
}

template <class ParserT>
void MessageInputReplyTo::parse(ParserT &parser) {
  bool has_message_id;
  bool has_story_full_id;
  bool has_quote_legacy;
  bool has_dialog_id;
  bool has_quote_position_legacy;
  bool has_quote;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_message_id);
  PARSE_FLAG(has_story_full_id);
  PARSE_FLAG(has_quote_legacy);
  PARSE_FLAG(has_dialog_id);
  PARSE_FLAG(has_quote_position_legacy);
  PARSE_FLAG(has_quote);
  END_PARSE_FLAGS();
  if (has_message_id) {
    td::parse(message_id_, parser);
  }
  if (has_story_full_id) {
    td::parse(story_full_id_, parser);
  }
  FormattedText quote_legacy;
  if (has_quote_legacy) {
    td::parse(quote_legacy, parser);
  }
  if (has_dialog_id) {
    td::parse(dialog_id_, parser);
  }
  int32 quote_position_legacy = 0;
  if (has_quote_position_legacy) {
    td::parse(quote_position_legacy, parser);
  }
  if (has_quote) {
    td::parse(quote_, parser);
  } else if (has_quote_legacy) {
    quote_ = MessageQuote(std::move(quote_legacy), quote_position_legacy);
  }
}

}  // namespace td
