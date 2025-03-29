//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageQuote.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void MessageQuote::store(StorerT &storer) const {
  bool has_text = !text_.text.empty();
  bool has_position = position_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_text);
  STORE_FLAG(has_position);
  STORE_FLAG(is_manual_);
  END_STORE_FLAGS();
  if (has_text) {
    td::store(text_, storer);
  }
  if (has_position) {
    td::store(position_, storer);
  }
}

template <class ParserT>
void MessageQuote::parse(ParserT &parser) {
  bool has_text;
  bool has_position;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_text);
  PARSE_FLAG(has_position);
  PARSE_FLAG(is_manual_);
  END_PARSE_FLAGS();
  if (has_text) {
    td::parse(text_, parser);
    remove_unallowed_quote_entities(text_);
  }
  if (has_position) {
    td::parse(position_, parser);
  }
}

}  // namespace td
