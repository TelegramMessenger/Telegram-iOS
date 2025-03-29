//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessAwayMessageSchedule.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void BusinessAwayMessageSchedule::store(StorerT &storer) const {
  bool has_start_date = start_date_ != 0;
  bool has_end_date = end_date_ != 0;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_start_date);
  STORE_FLAG(has_end_date);
  END_STORE_FLAGS();
  td::store(type_, storer);
  if (has_start_date) {
    td::store(start_date_, storer);
  }
  if (has_end_date) {
    td::store(end_date_, storer);
  }
}

template <class ParserT>
void BusinessAwayMessageSchedule::parse(ParserT &parser) {
  bool has_start_date;
  bool has_end_date;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_start_date);
  PARSE_FLAG(has_end_date);
  END_PARSE_FLAGS();
  td::parse(type_, parser);
  if (has_start_date) {
    td::parse(start_date_, parser);
  }
  if (has_end_date) {
    td::parse(end_date_, parser);
  }
}

}  // namespace td
