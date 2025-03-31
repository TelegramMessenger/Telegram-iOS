//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessInfo.h"

#include "td/telegram/BusinessAwayMessage.hpp"
#include "td/telegram/BusinessGreetingMessage.hpp"
#include "td/telegram/BusinessIntro.hpp"
#include "td/telegram/BusinessWorkHours.hpp"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void BusinessInfo::store(StorerT &storer) const {
  bool has_location = !is_empty_location(location_);
  bool has_work_hours = !work_hours_.is_empty();
  bool has_away_message = away_message_.is_valid();
  bool has_greeting_message = greeting_message_.is_valid();
  bool has_intro = !intro_.is_empty();
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_location);
  STORE_FLAG(has_work_hours);
  STORE_FLAG(has_away_message);
  STORE_FLAG(has_greeting_message);
  STORE_FLAG(has_intro);
  END_STORE_FLAGS();
  if (has_location) {
    td::store(location_, storer);
  }
  if (has_work_hours) {
    td::store(work_hours_, storer);
  }
  if (has_away_message) {
    td::store(away_message_, storer);
  }
  if (has_greeting_message) {
    td::store(greeting_message_, storer);
  }
  if (has_intro) {
    td::store(intro_, storer);
  }
}

template <class ParserT>
void BusinessInfo::parse(ParserT &parser) {
  bool has_location;
  bool has_work_hours;
  bool has_away_message;
  bool has_greeting_message;
  bool has_intro;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_location);
  PARSE_FLAG(has_work_hours);
  PARSE_FLAG(has_away_message);
  PARSE_FLAG(has_greeting_message);
  PARSE_FLAG(has_intro);
  END_PARSE_FLAGS();
  if (has_location) {
    td::parse(location_, parser);
  }
  if (has_work_hours) {
    td::parse(work_hours_, parser);
  }
  if (has_away_message) {
    td::parse(away_message_, parser);
  }
  if (has_greeting_message) {
    td::parse(greeting_message_, parser);
  }
  if (has_intro) {
    td::parse(intro_, parser);
  }
}

}  // namespace td
