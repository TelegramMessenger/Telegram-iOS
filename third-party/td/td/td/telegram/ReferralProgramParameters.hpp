//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ReferralProgramParameters.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void ReferralProgramParameters::store(StorerT &storer) const {
  bool has_month_count = month_count_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_month_count);
  END_STORE_FLAGS();
  td::store(commission_, storer);
  if (has_month_count) {
    td::store(month_count_, storer);
  }
}

template <class ParserT>
void ReferralProgramParameters::parse(ParserT &parser) {
  bool has_month_count;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_month_count);
  END_PARSE_FLAGS();
  td::parse(commission_, parser);
  if (has_month_count) {
    td::parse(month_count_, parser);
  }
  if (!is_valid()) {
    parser.set_error("Invalid referral program parameters stored in the database");
  }
}

}  // namespace td
