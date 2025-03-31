//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BusinessWorkHours.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/TimeZoneManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/format.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"

#include <algorithm>

namespace td {

td_api::object_ptr<td_api::businessOpeningHoursInterval>
BusinessWorkHours::WorkHoursInterval::get_business_opening_hours_interval_object() const {
  return td_api::make_object<td_api::businessOpeningHoursInterval>(start_minute_, end_minute_);
}

telegram_api::object_ptr<telegram_api::businessWeeklyOpen>
BusinessWorkHours::WorkHoursInterval::get_input_business_weekly_open() const {
  return telegram_api::make_object<telegram_api::businessWeeklyOpen>(start_minute_, end_minute_);
}

BusinessWorkHours::BusinessWorkHours(telegram_api::object_ptr<telegram_api::businessWorkHours> &&work_hours) {
  if (work_hours != nullptr) {
    work_hours_ = transform(work_hours->weekly_open_,
                            [](const telegram_api::object_ptr<telegram_api::businessWeeklyOpen> &weekly_open) {
                              return WorkHoursInterval(weekly_open->start_minute_, weekly_open->end_minute_);
                            });
    sanitize_work_hours();
    time_zone_id_ = std::move(work_hours->timezone_id_);
  }
}

BusinessWorkHours::BusinessWorkHours(td_api::object_ptr<td_api::businessOpeningHours> &&work_hours) {
  if (work_hours != nullptr) {
    work_hours_ = transform(work_hours->opening_hours_,
                            [](const td_api::object_ptr<td_api::businessOpeningHoursInterval> &interval) {
                              return WorkHoursInterval(interval->start_minute_, interval->end_minute_);
                            });
    sanitize_work_hours();
    time_zone_id_ = std::move(work_hours->time_zone_id_);
  }
}

bool BusinessWorkHours::is_empty() const {
  return work_hours_.empty();
}

td_api::object_ptr<td_api::businessOpeningHours> BusinessWorkHours::get_business_opening_hours_object() const {
  if (is_empty()) {
    return nullptr;
  }
  vector<td_api::object_ptr<td_api::businessOpeningHoursInterval>> intervals;
  for (const auto &work_hour : work_hours_) {
    auto interval = work_hour;
    while (interval.start_minute_ / (24 * 60) + 1 < interval.end_minute_ / (24 * 60)) {
      auto prefix = interval;
      prefix.end_minute_ = (interval.start_minute_ / (24 * 60) + 1) * 24 * 60;
      interval.start_minute_ = prefix.end_minute_;
      intervals.push_back(prefix.get_business_opening_hours_interval_object());
    }
    intervals.push_back(interval.get_business_opening_hours_interval_object());
  }
  return td_api::make_object<td_api::businessOpeningHours>(time_zone_id_, std::move(intervals));
}

td_api::object_ptr<td_api::businessOpeningHours> BusinessWorkHours::get_local_business_opening_hours_object(
    Td *td) const {
  if (is_empty() || td->auth_manager_->is_bot()) {
    return nullptr;
  }

  auto offset = (td->time_zone_manager_->get_time_zone_offset(time_zone_id_) -
                 narrow_cast<int32>(td->option_manager_->get_option_integer("utc_time_offset"))) /
                60;
  if (offset == 0) {
    return get_business_opening_hours_object();
  }

  BusinessWorkHours local_work_hours;
  for (auto &interval : work_hours_) {
    auto start_minute = interval.start_minute_ - offset;
    auto end_minute = interval.end_minute_ - offset;
    if (start_minute < 0) {
      if (end_minute <= 24 * 60) {
        start_minute += 7 * 24 * 60;
        end_minute += 7 * 24 * 60;
      } else {
        local_work_hours.work_hours_.emplace_back(start_minute + 7 * 24 * 60, 7 * 24 * 60);
        start_minute = 0;
      }
    } else if (end_minute > 8 * 24 * 60) {
      if (start_minute >= 7 * 24 * 60) {
        start_minute -= 7 * 24 * 60;
        end_minute -= 7 * 24 * 60;
      } else {
        local_work_hours.work_hours_.emplace_back(0, end_minute - 7 * 24 * 60);
        end_minute = 7 * 24 * 60;
      }
    }
    local_work_hours.work_hours_.emplace_back(start_minute, end_minute);
  }
  local_work_hours.sanitize_work_hours();
  return local_work_hours.get_business_opening_hours_object();
}

telegram_api::object_ptr<telegram_api::businessWorkHours> BusinessWorkHours::get_input_business_work_hours() const {
  if (is_empty()) {
    return nullptr;
  }
  return telegram_api::make_object<telegram_api::businessWorkHours>(
      0, false, time_zone_id_, transform(work_hours_, [](const WorkHoursInterval &interval) {
        return interval.get_input_business_weekly_open();
      }));
}

int32 BusinessWorkHours::get_next_open_close_in(Td *td, int32 unix_time, bool is_close) const {
  if (is_empty()) {
    return 0;
  }
  auto get_week_time = [](int32 time) {
    const auto week_length = 7 * 86400;
    return ((time % week_length) + week_length) % week_length;
  };
  // the Unix time 0 was on a Thursday, the first Monday was at 4 * 86400
  auto current_week_time = get_week_time(unix_time - 4 * 86400);
  auto offset = td->time_zone_manager_->get_time_zone_offset(time_zone_id_);
  int32 result = 1000000000;
  for (auto &interval : work_hours_) {
    auto change_week_time = get_week_time((is_close ? interval.end_minute_ : interval.start_minute_) * 60 - offset);
    auto wait_time = change_week_time - current_week_time;
    if (wait_time < 0) {
      wait_time += 7 * 86400;
    }
    if (wait_time < result) {
      result = wait_time;
    }
  }
  return result;
}

void BusinessWorkHours::sanitize_work_hours() {
  // remove invalid work hour intervals
  td::remove_if(work_hours_, [](const WorkHoursInterval &interval) {
    if (interval.start_minute_ >= interval.end_minute_ || interval.start_minute_ < 0 ||
        interval.end_minute_ > 8 * 24 * 60) {
      LOG(INFO) << "Ignore interval " << interval;
      return true;
    }
    return false;
  });

  combine_work_hour_intervals();
}

void BusinessWorkHours::combine_work_hour_intervals() {
  if (work_hours_.empty()) {
    return;
  }

  // sort intervals
  std::sort(work_hours_.begin(), work_hours_.end(), [](const WorkHoursInterval &lhs, const WorkHoursInterval &rhs) {
    return lhs.start_minute_ < rhs.start_minute_;
  });

  // combine intersecting intervals
  size_t j = 0;
  for (size_t i = 1; i < work_hours_.size(); i++) {
    CHECK(work_hours_[i].start_minute_ >= work_hours_[j].start_minute_);
    if (work_hours_[i].start_minute_ <= work_hours_[j].end_minute_) {
      work_hours_[j].end_minute_ = max(work_hours_[j].end_minute_, work_hours_[i].end_minute_);
    } else {
      work_hours_[++j] = work_hours_[i];
    }
  }
  work_hours_.resize(j + 1);

  // there must be no intervals longer than 1 week
  for (auto &interval : work_hours_) {
    interval.end_minute_ = min(interval.end_minute_, interval.start_minute_ + 7 * 24 * 60);
  }

  CHECK(!work_hours_.empty());

  // if the last interval can be exactly merged with the first one, merge them
  if (work_hours_[0].start_minute_ != 0 &&
      work_hours_[0].start_minute_ + 7 * 24 * 60 == work_hours_.back().end_minute_) {
    if (work_hours_.back().start_minute_ >= 7 * 24 * 60) {
      work_hours_[0].start_minute_ = work_hours_.back().start_minute_ - 7 * 24 * 60;
      work_hours_.pop_back();
      CHECK(!work_hours_.empty());
    } else {
      work_hours_[0].start_minute_ = 0;
      work_hours_.back().end_minute_ = 7 * 24 * 60;
    }
  }

  // if there are intervals that intersect the first interval or start after the end of the week,
  // then they must be normalized
  auto max_minute = work_hours_[0].start_minute_ + 7 * 24 * 60;
  if (work_hours_.back().end_minute_ > max_minute || work_hours_.back().start_minute_ >= 7 * 24 * 60) {
    auto size = work_hours_.size();
    for (size_t i = 0; i < size; i++) {
      if (work_hours_[i].start_minute_ >= 7 * 24 * 60) {
        work_hours_[i].start_minute_ -= 7 * 24 * 60;
        work_hours_[i].end_minute_ -= 7 * 24 * 60;
      } else if (work_hours_[i].end_minute_ > max_minute) {
        work_hours_.emplace_back(max_minute - 7 * 24 * 60, work_hours_[i].end_minute_ - 7 * 24 * 60);
        work_hours_[i].end_minute_ = max_minute;
      }
    }
    LOG(INFO) << "Need to normalize " << work_hours_;
    combine_work_hour_intervals();
  }
}

bool operator==(const BusinessWorkHours::WorkHoursInterval &lhs, const BusinessWorkHours::WorkHoursInterval &rhs) {
  return lhs.start_minute_ == rhs.start_minute_ && lhs.end_minute_ == rhs.end_minute_;
}

bool operator!=(const BusinessWorkHours::WorkHoursInterval &lhs, const BusinessWorkHours::WorkHoursInterval &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessWorkHours::WorkHoursInterval &interval) {
  return string_builder << '[' << interval.start_minute_ << ',' << interval.end_minute_ << ')';
}

bool operator==(const BusinessWorkHours &lhs, const BusinessWorkHours &rhs) {
  return lhs.work_hours_ == rhs.work_hours_ && lhs.time_zone_id_ == rhs.time_zone_id_;
}

bool operator!=(const BusinessWorkHours &lhs, const BusinessWorkHours &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessWorkHours &work_hours) {
  return string_builder << "BusinessWorkHours[" << work_hours.work_hours_ << " in " << work_hours.time_zone_id_ << ']';
}

}  // namespace td
