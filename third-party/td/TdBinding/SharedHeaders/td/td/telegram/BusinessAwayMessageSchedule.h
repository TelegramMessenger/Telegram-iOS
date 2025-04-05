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

class BusinessAwayMessageSchedule {
 public:
  BusinessAwayMessageSchedule() = default;

  explicit BusinessAwayMessageSchedule(telegram_api::object_ptr<telegram_api::BusinessAwayMessageSchedule> schedule);

  explicit BusinessAwayMessageSchedule(td_api::object_ptr<td_api::BusinessAwayMessageSchedule> schedule);

  td_api::object_ptr<td_api::BusinessAwayMessageSchedule> get_business_away_message_schedule_object() const;

  telegram_api::object_ptr<telegram_api::BusinessAwayMessageSchedule> get_input_business_away_message_schedule() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);

 private:
  enum class Type : int32 { Always, OutsideOfWorkHours, Custom };
  Type type_ = Type::Always;
  int32 start_date_ = 0;
  int32 end_date_ = 0;

  friend bool operator==(const BusinessAwayMessageSchedule &lhs, const BusinessAwayMessageSchedule &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BusinessAwayMessageSchedule &schedule);
};

bool operator==(const BusinessAwayMessageSchedule &lhs, const BusinessAwayMessageSchedule &rhs);

inline bool operator!=(const BusinessAwayMessageSchedule &lhs, const BusinessAwayMessageSchedule &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessAwayMessageSchedule &schedule);

}  // namespace td
