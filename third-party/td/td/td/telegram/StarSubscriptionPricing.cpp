//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StarSubscriptionPricing.h"

#include "td/telegram/StarManager.h"

namespace td {

StarSubscriptionPricing::StarSubscriptionPricing(
    telegram_api::object_ptr<telegram_api::starsSubscriptionPricing> &&pricing) {
  if (pricing != nullptr) {
    period_ = pricing->period_;
    amount_ = StarManager::get_star_count(pricing->amount_);
  }
}

StarSubscriptionPricing::StarSubscriptionPricing(td_api::object_ptr<td_api::starSubscriptionPricing> &&pricing) {
  if (pricing != nullptr) {
    period_ = pricing->period_;
    amount_ = pricing->star_count_;
    if (amount_ > 1000000000) {
      amount_ = 0;
    }
  }
}

td_api::object_ptr<td_api::starSubscriptionPricing> StarSubscriptionPricing::get_star_subscription_pricing_object()
    const {
  if (is_empty()) {
    return nullptr;
  }
  return td_api::make_object<td_api::starSubscriptionPricing>(period_, amount_);
}

telegram_api::object_ptr<telegram_api::starsSubscriptionPricing>
StarSubscriptionPricing::get_input_stars_subscription_pricing() const {
  if (is_empty()) {
    return nullptr;
  }
  return telegram_api::make_object<telegram_api::starsSubscriptionPricing>(period_, amount_);
}

bool operator==(const StarSubscriptionPricing &lhs, const StarSubscriptionPricing &rhs) {
  return lhs.period_ == rhs.period_ && lhs.amount_ == rhs.amount_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const StarSubscriptionPricing &pricing) {
  if (pricing.is_empty()) {
    return string_builder << "no subscription";
  }
  return string_builder << "subscription for " << pricing.period_ << " days for " << pricing.amount_ << " stars";
}

}  // namespace td
