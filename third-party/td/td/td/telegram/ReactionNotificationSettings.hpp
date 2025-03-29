//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/NotificationSound.h"
#include "td/telegram/ReactionNotificationSettings.h"
#include "td/telegram/ReactionNotificationsFrom.hpp"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void ReactionNotificationSettings::store(StorerT &storer) const {
  bool has_sound = sound_ != nullptr;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(has_sound);
  STORE_FLAG(show_preview_);
  END_STORE_FLAGS();
  td::store(message_reactions_, storer);
  td::store(story_reactions_, storer);
  if (has_sound) {
    td::store(sound_, storer);
  }
}

template <class ParserT>
void ReactionNotificationSettings::parse(ParserT &parser) {
  bool has_sound;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(has_sound);
  PARSE_FLAG(show_preview_);
  END_PARSE_FLAGS();
  td::parse(message_reactions_, parser);
  td::parse(story_reactions_, parser);
  if (has_sound) {
    parse_notification_sound(sound_, parser);
  }
}

}  // namespace td
