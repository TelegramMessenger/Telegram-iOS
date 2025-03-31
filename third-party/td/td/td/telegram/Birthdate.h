//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Birthdate {
 public:
  Birthdate() = default;

  explicit Birthdate(telegram_api::object_ptr<telegram_api::birthday> birthday);

  explicit Birthdate(td_api::object_ptr<td_api::birthdate> birthdate);

  td_api::object_ptr<td_api::birthdate> get_birthdate_object() const;

  telegram_api::object_ptr<telegram_api::birthday> get_input_birthday() const;

  bool is_empty() const {
    return birthdate_ == 0;
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);

 private:
  int32 birthdate_ = 0;

  int32 get_day() const {
    return birthdate_ & 31;
  }

  int32 get_month() const {
    return (birthdate_ >> 5) & 15;
  }

  int32 get_year() const {
    return birthdate_ >> 9;
  }

  void init(int32 day, int32 month, int32 year);

  friend bool operator==(const Birthdate &lhs, const Birthdate &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const Birthdate &birthdate);
};

bool operator==(const Birthdate &lhs, const Birthdate &rhs);

inline bool operator!=(const Birthdate &lhs, const Birthdate &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const Birthdate &birthdate);

}  // namespace td
