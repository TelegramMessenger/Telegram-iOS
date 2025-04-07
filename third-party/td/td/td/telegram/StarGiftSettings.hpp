//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DisallowedGiftsSettings.hpp"
#include "td/telegram/StarGiftSettings.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void StarGiftSettings::store(StorerT &storer) const {
  bool has_default_disallowed_gifts = disallowed_gifts_.is_default();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(display_gifts_button_);
  STORE_FLAG(has_default_disallowed_gifts);
  END_STORE_FLAGS();
  if (!has_default_disallowed_gifts) {
    td::store(disallowed_gifts_, storer);
  }
}

template <class ParserT>
void StarGiftSettings::parse(ParserT &parser) {
  bool has_default_disallowed_gifts;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(display_gifts_button_);
  PARSE_FLAG(has_default_disallowed_gifts);
  END_PARSE_FLAGS();
  if (!has_default_disallowed_gifts) {
    td::parse(disallowed_gifts_, parser);
  }
}

}  // namespace td
