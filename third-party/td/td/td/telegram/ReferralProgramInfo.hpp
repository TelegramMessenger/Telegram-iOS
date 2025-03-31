//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ReferralProgramInfo.h"

#include "td/telegram/ReferralProgramParameters.hpp"
#include "td/telegram/StarAmount.hpp"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void ReferralProgramInfo::store(StorerT &storer) const {
  bool has_end_date = end_date_ != 0;
  bool has_daily_star_amount = daily_star_amount_ != StarAmount();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_end_date);
  STORE_FLAG(has_daily_star_amount);
  END_STORE_FLAGS();
  td::store(parameters_, storer);
  if (has_end_date) {
    td::store(end_date_, storer);
  }
  if (has_daily_star_amount) {
    td::store(daily_star_amount_, storer);
  }
}

template <class ParserT>
void ReferralProgramInfo::parse(ParserT &parser) {
  bool has_end_date;
  bool has_daily_star_amount;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_end_date);
  PARSE_FLAG(has_daily_star_amount);
  END_PARSE_FLAGS();
  td::parse(parameters_, parser);
  if (has_end_date) {
    td::parse(end_date_, parser);
  }
  if (has_daily_star_amount) {
    td::parse(daily_star_amount_, parser);
  }
  if (!is_valid()) {
    parser.set_error("Invalid referral program info stored in the database");
  }
}

}  // namespace td
