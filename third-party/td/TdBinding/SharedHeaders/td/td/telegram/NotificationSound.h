//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/logevent/LogEvent.h"
#include "td/telegram/NotificationSoundType.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class NotificationSound {
 public:
  NotificationSound() = default;
  NotificationSound(const NotificationSound &) = delete;
  NotificationSound &operator=(const NotificationSound &) = delete;
  NotificationSound(NotificationSound &&) = delete;
  NotificationSound &operator=(NotificationSound &&) = delete;

  virtual NotificationSoundType get_type() const = 0;
  virtual ~NotificationSound() = default;

  template <class StorerT>
  void store(StorerT &storer) const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const unique_ptr<NotificationSound> &notification_sound);

void store_notification_sound(const NotificationSound *notification_sound, LogEventStorerCalcLength &storer);

void store_notification_sound(const NotificationSound *notification_sound, LogEventStorerUnsafe &storer);

template <class StorerT>
void NotificationSound::store(StorerT &storer) const {
  store_notification_sound(this, storer);
}

void parse_notification_sound(unique_ptr<NotificationSound> &notification_sound, LogEventParser &parser);

bool is_notification_sound_default(const unique_ptr<NotificationSound> &notification_sound);

bool are_equivalent_notification_sounds(const unique_ptr<NotificationSound> &lhs,
                                        const unique_ptr<NotificationSound> &rhs);

bool are_different_equivalent_notification_sounds(const unique_ptr<NotificationSound> &lhs,
                                                  const unique_ptr<NotificationSound> &rhs);

int64 get_notification_sound_ringtone_id(const unique_ptr<NotificationSound> &notification_sound);

unique_ptr<NotificationSound> get_legacy_notification_sound(const string &sound);

unique_ptr<NotificationSound> get_notification_sound(telegram_api::NotificationSound *notification_sound);

unique_ptr<NotificationSound> get_notification_sound(bool use_default_sound, int64 ringtone_id);

unique_ptr<NotificationSound> get_notification_sound(telegram_api::peerNotifySettings *settings, bool for_stories);

telegram_api::object_ptr<telegram_api::NotificationSound> get_input_notification_sound(
    const unique_ptr<NotificationSound> &notification_sound, bool return_non_null = false);

unique_ptr<NotificationSound> dup_notification_sound(const unique_ptr<NotificationSound> &notification_sound);

}  // namespace td
