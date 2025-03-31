//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StoryStealthMode.h"

#include "td/telegram/Global.h"

namespace td {

StoryStealthMode::StoryStealthMode(telegram_api::object_ptr<telegram_api::storiesStealthMode> &&stealth_mode)
    : active_until_date_(stealth_mode->active_until_date_), cooldown_until_date_(stealth_mode->cooldown_until_date_) {
  update();
}

bool StoryStealthMode::update() {
  auto current_time = G()->unix_time();
  bool result = false;
  if (active_until_date_ != 0 && active_until_date_ <= current_time) {
    active_until_date_ = 0;
    result = true;
  }
  if (cooldown_until_date_ != 0 && cooldown_until_date_ <= current_time) {
    cooldown_until_date_ = 0;
    result = true;
  }
  return result;
}

int32 StoryStealthMode::get_update_date() const {
  if (active_until_date_ > 0) {
    if (cooldown_until_date_ > 0) {
      return min(active_until_date_, cooldown_until_date_);
    }
    return active_until_date_;
  }
  if (cooldown_until_date_ > 0) {
    return cooldown_until_date_;
  }
  return 0;
}

td_api::object_ptr<td_api::updateStoryStealthMode> StoryStealthMode::get_update_story_stealth_mode_object() const {
  return td_api::make_object<td_api::updateStoryStealthMode>(active_until_date_, cooldown_until_date_);
}

bool operator==(const StoryStealthMode &lhs, const StoryStealthMode &rhs) {
  return lhs.active_until_date_ == rhs.active_until_date_ && lhs.cooldown_until_date_ == rhs.cooldown_until_date_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const StoryStealthMode &mode) {
  if (mode.active_until_date_) {
    return string_builder << "Stealth mode is active until " << mode.active_until_date_;
  }
  if (mode.cooldown_until_date_) {
    return string_builder << "Stealth mode can't be activated until " << mode.cooldown_until_date_;
  }
  return string_builder << "Stealth mode can be activated";
}

}  // namespace td
