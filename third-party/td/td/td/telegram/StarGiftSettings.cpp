//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StarGiftSettings.h"

namespace td {

StarGiftSettings::StarGiftSettings(bool display_gifts_button,
                                   telegram_api::object_ptr<telegram_api::disallowedGiftsSettings> &&settings)
    : display_gifts_button_(display_gifts_button), disallowed_gifts_(std::move(settings)) {
}

StarGiftSettings::StarGiftSettings(const td_api::object_ptr<td_api::giftSettings> &settings) {
  if (settings != nullptr) {
    display_gifts_button_ = settings->show_gift_button_;
    disallowed_gifts_ = DisallowedGiftsSettings(settings->accepted_gift_types_);
  }
}

td_api::object_ptr<td_api::giftSettings> StarGiftSettings::get_gift_settings_object() const {
  return td_api::make_object<td_api::giftSettings>(display_gifts_button_,
                                                   disallowed_gifts_.get_accepted_gift_types_object());
}

bool operator==(const StarGiftSettings &lhs, const StarGiftSettings &rhs) {
  return lhs.display_gifts_button_ == rhs.display_gifts_button_ && lhs.disallowed_gifts_ == rhs.disallowed_gifts_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const StarGiftSettings &settings) {
  if (settings.display_gifts_button_) {
    string_builder << "(show button)";
  }
  return string_builder << settings.disallowed_gifts_;
}

}  // namespace td
