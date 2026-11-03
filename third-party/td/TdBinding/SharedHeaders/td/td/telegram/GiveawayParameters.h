//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Dependencies;

class Td;

class GiveawayParameters {
  ChannelId boosted_channel_id_;
  vector<ChannelId> additional_channel_ids_;
  bool only_new_subscribers_ = false;
  bool winners_are_visible_ = false;
  int32 date_ = 0;
  vector<string> country_codes_;
  string prize_description_;

  static Result<ChannelId> get_boosted_channel_id(Td *td, DialogId dialog_id);

  friend bool operator==(const GiveawayParameters &lhs, const GiveawayParameters &rhs);
  friend bool operator!=(const GiveawayParameters &lhs, const GiveawayParameters &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const GiveawayParameters &giveaway_parameters);

 public:
  GiveawayParameters() = default;

  GiveawayParameters(ChannelId boosted_channel_id, vector<ChannelId> &&additional_channel_ids,
                     bool only_new_subscribers, bool winners_are_visible, int32 date, vector<string> &&country_codes,
                     string &&prize_description)
      : boosted_channel_id_(boosted_channel_id)
      , additional_channel_ids_(std::move(additional_channel_ids))
      , only_new_subscribers_(only_new_subscribers)
      , winners_are_visible_(winners_are_visible)
      , date_(date)
      , country_codes_(std::move(country_codes))
      , prize_description_(std::move(prize_description)) {
  }

  static Result<GiveawayParameters> get_giveaway_parameters(Td *td, const td_api::giveawayParameters *parameters);

  bool is_valid() const {
    for (auto channel_id : additional_channel_ids_) {
      if (!channel_id.is_valid()) {
        return false;
      }
    }
    return boosted_channel_id_.is_valid() && date_ > 0;
  }

  DialogId get_boosted_dialog_id() const {
    return DialogId(boosted_channel_id_);
  }

  vector<ChannelId> get_channel_ids() const;

  void add_dependencies(Dependencies &dependencies) const;

  telegram_api::object_ptr<telegram_api::inputStorePaymentPremiumGiveaway> get_input_store_payment_premium_giveaway(
      Td *td, const string &currency, int64 amount) const;

  telegram_api::object_ptr<telegram_api::inputStorePaymentStarsGiveaway> get_input_store_payment_stars_giveaway(
      Td *td, const string &currency, int64 amount, int32 user_count, int64 star_count) const;

  td_api::object_ptr<td_api::giveawayParameters> get_giveaway_parameters_object(Td *td) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const GiveawayParameters &lhs, const GiveawayParameters &rhs);
bool operator!=(const GiveawayParameters &lhs, const GiveawayParameters &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const GiveawayParameters &giveaway_parameters);

}  // namespace td
