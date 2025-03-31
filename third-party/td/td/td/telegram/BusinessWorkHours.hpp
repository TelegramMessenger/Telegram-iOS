//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessWorkHours.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void BusinessWorkHours::WorkHoursInterval::store(StorerT &storer) const {
  td::store(start_minute_, storer);
  td::store(end_minute_, storer);
}

template <class ParserT>
void BusinessWorkHours::WorkHoursInterval::parse(ParserT &parser) {
  td::parse(start_minute_, parser);
  td::parse(end_minute_, parser);
}

template <class StorerT>
void BusinessWorkHours::store(StorerT &storer) const {
  BEGIN_STORE_FLAGS();
  END_STORE_FLAGS();
  td::store(work_hours_, storer);
  td::store(time_zone_id_, storer);
}

template <class ParserT>
void BusinessWorkHours::parse(ParserT &parser) {
  BEGIN_PARSE_FLAGS();
  END_PARSE_FLAGS();
  td::parse(work_hours_, parser);
  td::parse(time_zone_id_, parser);
}

}  // namespace td
