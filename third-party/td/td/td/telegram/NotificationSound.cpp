//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/NotificationSound.h"

#include "td/utils/logging.h"
#include "td/utils/tl_helpers.h"

namespace td {

class NotificationSoundNone final : public NotificationSound {
 public:
  NotificationSoundNone() = default;

  NotificationSoundType get_type() const final {
    return NotificationSoundType::None;
  }
};

class NotificationSoundLocal final : public NotificationSound {
 public:
  string title_;
  string data_;

  NotificationSoundLocal() = default;
  NotificationSoundLocal(string title, string data) : title_(std::move(title)), data_(std::move(data)) {
  }

  NotificationSoundType get_type() const final {
    return NotificationSoundType::Local;
  }
};

class NotificationSoundRingtone final : public NotificationSound {
 public:
  int64 ringtone_id_;

  NotificationSoundRingtone() = default;
  explicit NotificationSoundRingtone(int64 ringtone_id) : ringtone_id_(ringtone_id) {
  }

  NotificationSoundType get_type() const final {
    return NotificationSoundType::Ringtone;
  }
};

template <class StorerT>
static void store(const NotificationSound *notification_sound, StorerT &storer) {
  CHECK(notification_sound != nullptr);

  auto sound_type = notification_sound->get_type();
  store(sound_type, storer);

  switch (sound_type) {
    case NotificationSoundType::None:
      break;
    case NotificationSoundType::Local: {
      const auto *sound = static_cast<const NotificationSoundLocal *>(notification_sound);
      store(sound->title_, storer);
      store(sound->data_, storer);
      break;
    }
    case NotificationSoundType::Ringtone: {
      const auto *sound = static_cast<const NotificationSoundRingtone *>(notification_sound);
      store(sound->ringtone_id_, storer);
      break;
    }
    default:
      UNREACHABLE();
  }
}

template <class ParserT>
static void parse(unique_ptr<NotificationSound> &notification_sound, ParserT &parser) {
  NotificationSoundType sound_type;
  parse(sound_type, parser);

  switch (sound_type) {
    case NotificationSoundType::None:
      notification_sound = make_unique<NotificationSoundNone>();
      break;
    case NotificationSoundType::Local: {
      auto sound = make_unique<NotificationSoundLocal>();
      parse(sound->title_, parser);
      parse(sound->data_, parser);
      notification_sound = std::move(sound);
      break;
    }
    case NotificationSoundType::Ringtone: {
      auto sound = make_unique<NotificationSoundRingtone>();
      parse(sound->ringtone_id_, parser);
      notification_sound = std::move(sound);
      break;
    }
    default:
      LOG(FATAL) << "Have unknown notification sound type " << static_cast<int32>(sound_type);
  }
}

void store_notification_sound(const NotificationSound *notification_sound, LogEventStorerCalcLength &storer) {
  store(notification_sound, storer);
}

void store_notification_sound(const NotificationSound *notification_sound, LogEventStorerUnsafe &storer) {
  store(notification_sound, storer);
}

void parse_notification_sound(unique_ptr<NotificationSound> &notification_sound, LogEventParser &parser) {
  parse(notification_sound, parser);
}

StringBuilder &operator<<(StringBuilder &string_builder, const unique_ptr<NotificationSound> &notification_sound) {
  if (notification_sound == nullptr) {
    return string_builder << "DefaultSound";
  }
  switch (notification_sound->get_type()) {
    case NotificationSoundType::None:
      return string_builder << "NoSound";
    case NotificationSoundType::Local: {
      const auto *sound = static_cast<const NotificationSoundLocal *>(notification_sound.get());
      return string_builder << "LocalSound[" << sound->title_ << '|' << sound->data_ << ']';
    }
    case NotificationSoundType::Ringtone: {
      const auto *sound = static_cast<const NotificationSoundRingtone *>(notification_sound.get());
      return string_builder << "Ringtone[" << sound->ringtone_id_ << ']';
    }
    default:
      UNREACHABLE();
      return string_builder;
  }
}

bool is_notification_sound_default(const unique_ptr<NotificationSound> &notification_sound) {
  if (notification_sound == nullptr) {
    return true;
  }
  return notification_sound->get_type() == NotificationSoundType::Local;
}

bool are_equivalent_notification_sounds(const unique_ptr<NotificationSound> &lhs,
                                        const unique_ptr<NotificationSound> &rhs) {
  if (is_notification_sound_default(lhs)) {
    return is_notification_sound_default(rhs);
  }
  if (is_notification_sound_default(rhs)) {
    return false;
  }

  auto sound_type = lhs->get_type();
  if (sound_type != rhs->get_type()) {
    return false;
  }

  switch (sound_type) {
    case NotificationSoundType::None:
      return true;
    case NotificationSoundType::Ringtone:
      return static_cast<const NotificationSoundRingtone *>(lhs.get())->ringtone_id_ ==
             static_cast<const NotificationSoundRingtone *>(rhs.get())->ringtone_id_;
    case NotificationSoundType::Local:
    default:
      UNREACHABLE();
      break;
  }
  return false;
}

bool are_different_equivalent_notification_sounds(const unique_ptr<NotificationSound> &lhs,
                                                  const unique_ptr<NotificationSound> &rhs) {
  if (lhs == nullptr) {
    return rhs != nullptr && rhs->get_type() == NotificationSoundType::Local;
  }
  if (rhs == nullptr) {
    return lhs->get_type() == NotificationSoundType::Local;
  }
  if (lhs->get_type() != NotificationSoundType::Local || rhs->get_type() != NotificationSoundType::Local) {
    return false;
  }

  const auto *lhs_local = static_cast<const NotificationSoundLocal *>(lhs.get());
  const auto *rhs_local = static_cast<const NotificationSoundLocal *>(rhs.get());
  return lhs_local->title_ != rhs_local->title_ || lhs_local->data_ != rhs_local->data_;
}

int64 get_notification_sound_ringtone_id(const unique_ptr<NotificationSound> &notification_sound) {
  if (notification_sound == nullptr) {
    return -1;
  }
  switch (notification_sound->get_type()) {
    case NotificationSoundType::None:
      return 0;
    case NotificationSoundType::Local:
      return -1;
    case NotificationSoundType::Ringtone: {
      return static_cast<const NotificationSoundRingtone *>(notification_sound.get())->ringtone_id_;
      default:
        UNREACHABLE();
        return -1;
    }
  }
}

unique_ptr<NotificationSound> get_legacy_notification_sound(const string &sound) {
  if (sound == "default") {
    return nullptr;
  }
  if (sound.empty()) {
    return make_unique<NotificationSoundNone>();
  }
  return td::make_unique<NotificationSoundLocal>(sound, sound);
}

unique_ptr<NotificationSound> get_notification_sound(bool use_default_sound, int64 ringtone_id) {
  if (use_default_sound || ringtone_id == -1) {
    return nullptr;
  }
  if (ringtone_id == 0) {
    return make_unique<NotificationSoundNone>();
  }
  return td::make_unique<NotificationSoundRingtone>(ringtone_id);
}

unique_ptr<NotificationSound> get_notification_sound(telegram_api::NotificationSound *notification_sound) {
  if (notification_sound == nullptr) {
    return nullptr;
  }

  switch (notification_sound->get_id()) {
    case telegram_api::notificationSoundDefault::ID:
      return nullptr;
    case telegram_api::notificationSoundNone::ID:
      return make_unique<NotificationSoundNone>();
    case telegram_api::notificationSoundLocal::ID: {
      const auto *sound = static_cast<telegram_api::notificationSoundLocal *>(notification_sound);
      return td::make_unique<NotificationSoundLocal>(std::move(sound->title_), std::move(sound->data_));
    }
    case telegram_api::notificationSoundRingtone::ID: {
      const auto *sound = static_cast<telegram_api::notificationSoundRingtone *>(notification_sound);
      if (sound->id_ == 0 || sound->id_ == -1) {
        LOG(ERROR) << "Receive ringtone with ID = " << sound->id_;
        return make_unique<NotificationSoundNone>();
      }
      return td::make_unique<NotificationSoundRingtone>(sound->id_);
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

unique_ptr<NotificationSound> get_notification_sound(telegram_api::peerNotifySettings *settings, bool for_stories) {
  CHECK(settings != nullptr);
  telegram_api::NotificationSound *sound =
#if TD_ANDROID
      for_stories ? settings->stories_android_sound_.get() : settings->android_sound_.get();
#elif TD_DARWIN_IOS || TD_DARWIN_TV_OS || TD_DARWIN_VISION_OS || TD_DARWIN_WATCH_OS || TD_DARWIN_UNKNOWN
      for_stories ? settings->stories_ios_sound_.get() : settings->ios_sound_.get();
#else
      for_stories ? settings->stories_other_sound_.get() : settings->other_sound_.get();
#endif
  return get_notification_sound(sound);
}

telegram_api::object_ptr<telegram_api::NotificationSound> get_input_notification_sound(
    const unique_ptr<NotificationSound> &notification_sound, bool return_non_null) {
  if (notification_sound == nullptr) {
    if (return_non_null) {
      return telegram_api::make_object<telegram_api::notificationSoundDefault>();
    }
    return nullptr;
  }

  // must not return nullptr if notification_sound != nullptr
  switch (notification_sound->get_type()) {
    case NotificationSoundType::None:
      return telegram_api::make_object<telegram_api::notificationSoundNone>();
    case NotificationSoundType::Local: {
      const auto *sound = static_cast<const NotificationSoundLocal *>(notification_sound.get());
      return telegram_api::make_object<telegram_api::notificationSoundLocal>(sound->title_, sound->data_);
    }
    case NotificationSoundType::Ringtone: {
      const auto *sound = static_cast<const NotificationSoundRingtone *>(notification_sound.get());
      return telegram_api::make_object<telegram_api::notificationSoundRingtone>(sound->ringtone_id_);
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

unique_ptr<NotificationSound> dup_notification_sound(const unique_ptr<NotificationSound> &notification_sound) {
  if (notification_sound == nullptr) {
    return nullptr;
  }

  switch (notification_sound->get_type()) {
    case NotificationSoundType::None:
      return make_unique<NotificationSoundNone>();
    case NotificationSoundType::Local: {
      const auto *sound = static_cast<const NotificationSoundLocal *>(notification_sound.get());
      return td::make_unique<NotificationSoundLocal>(sound->title_, sound->data_);
    }
    case NotificationSoundType::Ringtone: {
      const auto *sound = static_cast<const NotificationSoundRingtone *>(notification_sound.get());
      return td::make_unique<NotificationSoundRingtone>(sound->ringtone_id_);
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

}  // namespace td
