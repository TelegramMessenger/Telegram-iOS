//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/Photo.h"
#include "td/telegram/StarSubscriptionPricing.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

class StarSubscription {
  string id_;
  DialogId dialog_id_;
  int32 until_date_ = 0;
  bool can_reuse_ = false;
  bool is_canceled_ = false;
  bool is_bot_canceled_ = false;
  bool missing_balance_ = false;
  string invite_hash_;
  string title_;
  Photo photo_;
  string invoice_slug_;
  StarSubscriptionPricing pricing_;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const StarSubscription &subscription);

 public:
  StarSubscription() = default;

  StarSubscription(Td *td, telegram_api::object_ptr<telegram_api::starsSubscription> &&subscription);

  bool is_valid() const {
    return !id_.empty() && dialog_id_.is_valid() && until_date_ >= 0 && !pricing_.is_empty();
  }

  td_api::object_ptr<td_api::starSubscription> get_star_subscription_object(Td *td) const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const StarSubscription &subscription);

}  // namespace td
