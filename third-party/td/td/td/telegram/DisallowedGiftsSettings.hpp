//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DisallowedGiftsSettings.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void DisallowedGiftsSettings::store(StorerT &storer) const {
  BEGIN_STORE_FLAGS();
  STORE_FLAG(disallow_unlimited_stargifts_);
  STORE_FLAG(disallow_limited_stargifts_);
  STORE_FLAG(disallow_unique_stargifts_);
  STORE_FLAG(disallow_premium_gifts_);
  END_STORE_FLAGS();
}

template <class ParserT>
void DisallowedGiftsSettings::parse(ParserT &parser) {
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(disallow_unlimited_stargifts_);
  PARSE_FLAG(disallow_limited_stargifts_);
  PARSE_FLAG(disallow_unique_stargifts_);
  PARSE_FLAG(disallow_premium_gifts_);
  END_PARSE_FLAGS();
}

}  // namespace td
