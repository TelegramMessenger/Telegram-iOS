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

namespace td {

class PremiumGiftOption {
  int32 months_ = 0;
  bool is_current_ = false;
  bool is_upgrade_ = false;
  string currency_;
  int64 amount_ = 0;
  string bot_url_;
  string store_product_;
  string transaction_;

  friend bool operator<(const PremiumGiftOption &lhs, const PremiumGiftOption &rhs);

  friend bool operator==(const PremiumGiftOption &lhs, const PremiumGiftOption &rhs);

  double get_monthly_price() const;

  td_api::object_ptr<td_api::premiumPaymentOption> get_premium_payment_option_object(
      const PremiumGiftOption &base_option) const;

 public:
  PremiumGiftOption() = default;

  explicit PremiumGiftOption(telegram_api::object_ptr<telegram_api::premiumSubscriptionOption> &&option);

  td_api::object_ptr<td_api::premiumStatePaymentOption> get_premium_state_payment_option_object(
      const PremiumGiftOption &base_option) const;

  bool is_valid() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const PremiumGiftOption &lhs, const PremiumGiftOption &rhs);
bool operator!=(const PremiumGiftOption &lhs, const PremiumGiftOption &rhs);

vector<PremiumGiftOption> get_premium_gift_options(
    vector<telegram_api::object_ptr<telegram_api::premiumSubscriptionOption>> &&options);

vector<td_api::object_ptr<td_api::premiumStatePaymentOption>> get_premium_state_payment_options_object(
    const vector<PremiumGiftOption> &options);

}  // namespace td
