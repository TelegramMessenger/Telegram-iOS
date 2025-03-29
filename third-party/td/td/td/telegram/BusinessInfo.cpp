//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BusinessInfo.h"

#include "td/telegram/Dependencies.h"
#include "td/telegram/Global.h"

namespace td {

td_api::object_ptr<td_api::businessInfo> BusinessInfo::get_business_info_object(Td *td) const {
  if (is_empty()) {
    return nullptr;
  }
  auto unix_time = G()->unix_time();
  return td_api::make_object<td_api::businessInfo>(
      location_.get_business_location_object(), work_hours_.get_business_opening_hours_object(),
      work_hours_.get_local_business_opening_hours_object(td), work_hours_.get_next_open_close_in(td, unix_time, false),
      work_hours_.get_next_open_close_in(td, unix_time, true),
      greeting_message_.get_business_greeting_message_settings_object(td),
      away_message_.get_business_away_message_settings_object(td), intro_.get_business_start_page_object(td));
}

bool BusinessInfo::is_empty_location(const DialogLocation &location) {
  return location.empty() && location.get_address().empty();
}

bool BusinessInfo::is_empty() const {
  return is_empty_location(location_) && work_hours_.is_empty() && away_message_.is_empty() &&
         greeting_message_.is_empty() && intro_.is_empty();
}

bool BusinessInfo::set_location(unique_ptr<BusinessInfo> &business_info, DialogLocation &&location) {
  if (business_info == nullptr) {
    if (is_empty_location(location)) {
      return false;
    }
    business_info = make_unique<BusinessInfo>();
  }
  if (business_info->location_ != location) {
    business_info->location_ = std::move(location);
    return true;
  }
  return false;
}

bool BusinessInfo::set_work_hours(unique_ptr<BusinessInfo> &business_info, BusinessWorkHours &&work_hours) {
  if (business_info == nullptr) {
    if (work_hours.is_empty()) {
      return false;
    }
    business_info = make_unique<BusinessInfo>();
  }
  if (business_info->work_hours_ != work_hours) {
    business_info->work_hours_ = std::move(work_hours);
    return true;
  }
  return false;
}

bool BusinessInfo::set_away_message(unique_ptr<BusinessInfo> &business_info, BusinessAwayMessage &&away_message) {
  if (business_info == nullptr) {
    if (away_message.is_empty()) {
      return false;
    }
    business_info = make_unique<BusinessInfo>();
  }
  if (business_info->away_message_ != away_message) {
    business_info->away_message_ = std::move(away_message);
    return true;
  }
  return false;
}

bool BusinessInfo::set_greeting_message(unique_ptr<BusinessInfo> &business_info,
                                        BusinessGreetingMessage &&greeting_message) {
  if (business_info == nullptr) {
    if (greeting_message.is_empty()) {
      return false;
    }
    business_info = make_unique<BusinessInfo>();
  }
  if (business_info->greeting_message_ != greeting_message) {
    business_info->greeting_message_ = std::move(greeting_message);
    return true;
  }
  return false;
}

bool BusinessInfo::set_intro(unique_ptr<BusinessInfo> &business_info, BusinessIntro &&intro) {
  if (business_info == nullptr) {
    if (intro.is_empty()) {
      return false;
    }
    business_info = make_unique<BusinessInfo>();
  }
  if (business_info->intro_ != intro) {
    business_info->intro_ = std::move(intro);
    return true;
  }
  return false;
}

void BusinessInfo::add_dependencies(Dependencies &dependencies) const {
  away_message_.add_dependencies(dependencies);
  greeting_message_.add_dependencies(dependencies);
}

vector<FileId> BusinessInfo::get_file_ids(const Td *td) const {
  return intro_.get_file_ids(td);
}

}  // namespace td
