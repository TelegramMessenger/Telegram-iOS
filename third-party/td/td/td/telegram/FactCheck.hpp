//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/FactCheck.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void FactCheck::store(StorerT &storer) const {
  CHECK(!is_empty());
  bool has_country_code = !country_code_.empty();
  bool has_text = !text_.text.empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(need_check_);
  STORE_FLAG(has_country_code);
  STORE_FLAG(has_text);
  END_STORE_FLAGS();
  td::store(hash_, storer);
  if (has_country_code) {
    td::store(country_code_, storer);
  }
  if (has_text) {
    td::store(text_, storer);
  }
}

template <class ParserT>
void FactCheck::parse(ParserT &parser) {
  bool has_country_code;
  bool has_text;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(need_check_);
  PARSE_FLAG(has_country_code);
  PARSE_FLAG(has_text);
  END_PARSE_FLAGS();
  td::parse(hash_, parser);
  if (has_country_code) {
    td::parse(country_code_, parser);
  }
  if (has_text) {
    td::parse(text_, parser);
  }
  if (is_empty()) {
    parser.set_error("Load an empty fact check");
  }
}

}  // namespace td
