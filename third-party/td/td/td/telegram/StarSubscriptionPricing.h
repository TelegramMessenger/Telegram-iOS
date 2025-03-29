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

class StarSubscriptionPricing {
  int32 period_ = 0;
  int64 amount_ = 0;

  friend bool operator==(const StarSubscriptionPricing &lhs, const StarSubscriptionPricing &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const StarSubscriptionPricing &pricing);

 public:
  StarSubscriptionPricing() = default;

  explicit StarSubscriptionPricing(telegram_api::object_ptr<telegram_api::starsSubscriptionPricing> &&pricing);

  explicit StarSubscriptionPricing(td_api::object_ptr<td_api::starSubscriptionPricing> &&pricing);

  bool is_empty() const {
    return period_ <= 0 || amount_ <= 0;
  }

  td_api::object_ptr<td_api::starSubscriptionPricing> get_star_subscription_pricing_object() const;

  telegram_api::object_ptr<telegram_api::starsSubscriptionPricing> get_input_stars_subscription_pricing() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const StarSubscriptionPricing &lhs, const StarSubscriptionPricing &rhs);

inline bool operator!=(const StarSubscriptionPricing &lhs, const StarSubscriptionPricing &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const StarSubscriptionPricing &pricing);

}  // namespace td
