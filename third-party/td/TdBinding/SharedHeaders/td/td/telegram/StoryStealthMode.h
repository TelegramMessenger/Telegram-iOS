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

class StoryStealthMode {
  int32 active_until_date_ = 0;
  int32 cooldown_until_date_ = 0;

  friend bool operator==(const StoryStealthMode &lhs, const StoryStealthMode &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const StoryStealthMode &mode);

 public:
  StoryStealthMode() = default;

  explicit StoryStealthMode(telegram_api::object_ptr<telegram_api::storiesStealthMode> &&stealth_mode);

  bool is_empty() const {
    return active_until_date_ == 0 && cooldown_until_date_ == 0;
  }

  int32 get_update_date() const;

  bool update();

  td_api::object_ptr<td_api::updateStoryStealthMode> get_update_story_stealth_mode_object() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const StoryStealthMode &lhs, const StoryStealthMode &rhs);

inline bool operator!=(const StoryStealthMode &lhs, const StoryStealthMode &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const StoryStealthMode &mode);

}  // namespace td
