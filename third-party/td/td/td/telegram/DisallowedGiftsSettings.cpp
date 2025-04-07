//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DisallowedGiftsSettings.h"

namespace td {

DisallowedGiftsSettings::DisallowedGiftsSettings(
    telegram_api::object_ptr<telegram_api::disallowedGiftsSettings> &&settings) {
  if (settings != nullptr) {
    disallow_unlimited_stargifts_ = settings->disallow_unlimited_stargifts_;
    disallow_limited_stargifts_ = settings->disallow_limited_stargifts_;
    disallow_unique_stargifts_ = settings->disallow_unique_stargifts_;
    disallow_premium_gifts_ = settings->disallow_premium_gifts_;
  }
}

DisallowedGiftsSettings::DisallowedGiftsSettings(const td_api::object_ptr<td_api::acceptedGiftTypes> &types) {
  if (types != nullptr) {
    disallow_unlimited_stargifts_ = !types->unlimited_gifts_;
    disallow_limited_stargifts_ = !types->limited_gifts_;
    disallow_unique_stargifts_ = !types->upgraded_gifts_;
    disallow_premium_gifts_ = !types->premium_subscription_;
  }
}

td_api::object_ptr<td_api::acceptedGiftTypes> DisallowedGiftsSettings::get_accepted_gift_types_object() const {
  return td_api::make_object<td_api::acceptedGiftTypes>(!disallow_unlimited_stargifts_, !disallow_limited_stargifts_,
                                                        !disallow_unique_stargifts_, !disallow_premium_gifts_);
}

telegram_api::object_ptr<telegram_api::disallowedGiftsSettings>
DisallowedGiftsSettings::get_input_disallowed_gifts_settings() const {
  if (is_default()) {
    return nullptr;
  }
  return telegram_api::make_object<telegram_api::disallowedGiftsSettings>(
      0, disallow_unlimited_stargifts_, disallow_limited_stargifts_, disallow_unique_stargifts_,
      disallow_premium_gifts_);
}

bool operator==(const DisallowedGiftsSettings &lhs, const DisallowedGiftsSettings &rhs) {
  return lhs.disallow_unlimited_stargifts_ == rhs.disallow_unlimited_stargifts_ &&
         lhs.disallow_limited_stargifts_ == rhs.disallow_limited_stargifts_ &&
         lhs.disallow_unique_stargifts_ == rhs.disallow_unique_stargifts_ &&
         lhs.disallow_premium_gifts_ == rhs.disallow_premium_gifts_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const DisallowedGiftsSettings &settings) {
  if (!settings.disallow_unlimited_stargifts_) {
    string_builder << "(unlimited)";
  }
  if (!settings.disallow_limited_stargifts_) {
    string_builder << "(limited)";
  }
  if (!settings.disallow_unique_stargifts_) {
    string_builder << "(unique)";
  }
  if (!settings.disallow_premium_gifts_) {
    string_builder << "(premium)";
  }
  return string_builder;
}

}  // namespace td
