//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BusinessAwayMessageSchedule.h"

namespace td {

BusinessAwayMessageSchedule::BusinessAwayMessageSchedule(
    telegram_api::object_ptr<telegram_api::BusinessAwayMessageSchedule> schedule) {
  CHECK(schedule != nullptr);
  switch (schedule->get_id()) {
    case telegram_api::businessAwayMessageScheduleAlways::ID:
      type_ = Type::Always;
      break;
    case telegram_api::businessAwayMessageScheduleOutsideWorkHours::ID:
      type_ = Type::OutsideOfWorkHours;
      break;
    case telegram_api::businessAwayMessageScheduleCustom::ID: {
      auto custom_schedule = telegram_api::move_object_as<telegram_api::businessAwayMessageScheduleCustom>(schedule);
      type_ = Type::Custom;
      start_date_ = custom_schedule->start_date_;
      end_date_ = custom_schedule->end_date_;
      break;
    }
    default:
      UNREACHABLE();
  }
}

BusinessAwayMessageSchedule::BusinessAwayMessageSchedule(
    td_api::object_ptr<td_api::BusinessAwayMessageSchedule> schedule) {
  if (schedule == nullptr) {
    return;
  }
  switch (schedule->get_id()) {
    case td_api::businessAwayMessageScheduleAlways::ID:
      type_ = Type::Always;
      break;
    case td_api::businessAwayMessageScheduleOutsideOfOpeningHours::ID:
      type_ = Type::OutsideOfWorkHours;
      break;
    case td_api::businessAwayMessageScheduleCustom::ID: {
      auto custom_schedule = td_api::move_object_as<td_api::businessAwayMessageScheduleCustom>(schedule);
      type_ = Type::Custom;
      start_date_ = custom_schedule->start_date_;
      end_date_ = custom_schedule->end_date_;
      break;
    }
    default:
      UNREACHABLE();
  }
}

td_api::object_ptr<td_api::BusinessAwayMessageSchedule>
BusinessAwayMessageSchedule::get_business_away_message_schedule_object() const {
  switch (type_) {
    case Type::Always:
      return td_api::make_object<td_api::businessAwayMessageScheduleAlways>();
    case Type::OutsideOfWorkHours:
      return td_api::make_object<td_api::businessAwayMessageScheduleOutsideOfOpeningHours>();
    case Type::Custom:
      return td_api::make_object<td_api::businessAwayMessageScheduleCustom>(start_date_, end_date_);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

telegram_api::object_ptr<telegram_api::BusinessAwayMessageSchedule>
BusinessAwayMessageSchedule::get_input_business_away_message_schedule() const {
  switch (type_) {
    case Type::Always:
      return telegram_api::make_object<telegram_api::businessAwayMessageScheduleAlways>();
    case Type::OutsideOfWorkHours:
      return telegram_api::make_object<telegram_api::businessAwayMessageScheduleOutsideWorkHours>();
    case Type::Custom:
      return telegram_api::make_object<telegram_api::businessAwayMessageScheduleCustom>(start_date_, end_date_);
    default:
      UNREACHABLE();
      return nullptr;
  }
}

bool operator==(const BusinessAwayMessageSchedule &lhs, const BusinessAwayMessageSchedule &rhs) {
  return lhs.type_ == rhs.type_ && lhs.start_date_ == rhs.start_date_ && lhs.end_date_ == rhs.end_date_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessAwayMessageSchedule &schedule) {
  switch (schedule.type_) {
    case BusinessAwayMessageSchedule::Type::Always:
      return string_builder << "sent always";
    case BusinessAwayMessageSchedule::Type::OutsideOfWorkHours:
      return string_builder << "sent outside of opening hours";
    case BusinessAwayMessageSchedule::Type::Custom:
      return string_builder << "sent from " << schedule.start_date_ << " to " << schedule.end_date_;
    default:
      UNREACHABLE();
      return string_builder;
  }
}

}  // namespace td
