//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/StoryStealthMode.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void StoryStealthMode::store(StorerT &storer) const {
  using td::store;
  bool has_active_until_date = active_until_date_ != 0;
  bool has_cooldown_until_date = cooldown_until_date_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_active_until_date);
  STORE_FLAG(has_cooldown_until_date);
  END_STORE_FLAGS();
  if (has_active_until_date) {
    store(active_until_date_, storer);
  }
  if (has_cooldown_until_date) {
    store(cooldown_until_date_, storer);
  }
}

template <class ParserT>
void StoryStealthMode::parse(ParserT &parser) {
  using td::parse;
  bool has_active_until_date;
  bool has_cooldown_until_date;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_active_until_date);
  PARSE_FLAG(has_cooldown_until_date);
  END_PARSE_FLAGS();
  if (has_active_until_date) {
    parse(active_until_date_, parser);
  }
  if (has_cooldown_until_date) {
    parse(cooldown_until_date_, parser);
  }
}

}  // namespace td
