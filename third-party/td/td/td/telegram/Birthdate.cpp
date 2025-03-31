//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/Birthdate.h"

#include "td/utils/HttpDate.h"

namespace td {

void Birthdate::init(int32 day, int32 month, int32 year) {
  if (year < 1800 || year > 3000) {
    year = 0;
  }
  if (month <= 0 || month > 12 || day <= 0 || day > HttpDate::days_in_month(year, month)) {
    return;
  }
  birthdate_ = day | (month << 5) | (year << 9);
}

Birthdate::Birthdate(telegram_api::object_ptr<telegram_api::birthday> birthday) {
  if (birthday == nullptr) {
    return;
  }
  init(birthday->day_, birthday->month_, birthday->year_);
}

Birthdate::Birthdate(td_api::object_ptr<td_api::birthdate> birthdate) {
  if (birthdate == nullptr) {
    return;
  }
  init(birthdate->day_, birthdate->month_, birthdate->year_);
}

td_api::object_ptr<td_api::birthdate> Birthdate::get_birthdate_object() const {
  if (is_empty()) {
    return nullptr;
  }
  return td_api::make_object<td_api::birthdate>(get_day(), get_month(), get_year());
}

telegram_api::object_ptr<telegram_api::birthday> Birthdate::get_input_birthday() const {
  int32 flags = 0;
  auto year = get_year();
  if (year != 0) {
    flags |= telegram_api::birthday::YEAR_MASK;
  }
  return telegram_api::make_object<telegram_api::birthday>(flags, get_day(), get_month(), year);
}

bool operator==(const Birthdate &lhs, const Birthdate &rhs) {
  return lhs.birthdate_ == rhs.birthdate_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const Birthdate &birthdate) {
  if (birthdate.is_empty()) {
    return string_builder << "unknown birthdate";
  }
  string_builder << "birthdate " << birthdate.get_day() << '.' << birthdate.get_month();
  auto year = birthdate.get_year();
  if (year != 0) {
    string_builder << '.' << year;
  }
  return string_builder;
}

}  // namespace td
