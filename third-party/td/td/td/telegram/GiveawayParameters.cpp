//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/GiveawayParameters.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/misc.h"
#include "td/telegram/OptionManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/Random.h"

namespace td {

Result<ChannelId> GiveawayParameters::get_boosted_channel_id(Td *td, DialogId dialog_id) {
  if (!td->dialog_manager_->have_dialog_force(dialog_id, "get_boosted_channel_id")) {
    return Status::Error(400, "Chat to boost not found");
  }
  if (dialog_id.get_type() != DialogType::Channel) {
    return Status::Error(400, "Can't boost the chat");
  }
  auto channel_id = dialog_id.get_channel_id();
  auto status = td->chat_manager_->get_channel_status(channel_id);
  if (td->chat_manager_->is_broadcast_channel(channel_id) ? !status.can_post_messages() : !status.is_administrator()) {
    return Status::Error(400, "Not enough rights in the chat");
  }
  return channel_id;
}

Result<GiveawayParameters> GiveawayParameters::get_giveaway_parameters(Td *td,
                                                                       const td_api::giveawayParameters *parameters) {
  if (parameters == nullptr) {
    return Status::Error(400, "Giveaway parameters must be non-empty");
  }
  TRY_RESULT(boosted_channel_id, get_boosted_channel_id(td, DialogId(parameters->boosted_chat_id_)));
  vector<ChannelId> additional_channel_ids;
  for (auto additional_chat_id : parameters->additional_chat_ids_) {
    TRY_RESULT(channel_id, get_boosted_channel_id(td, DialogId(additional_chat_id)));
    additional_channel_ids.push_back(channel_id);
  }
  if (static_cast<int64>(additional_channel_ids.size()) >
      td->option_manager_->get_option_integer("giveaway_additional_chat_count_max")) {
    return Status::Error(400, "Too many additional chats specified");
  }
  if (parameters->winners_selection_date_ < G()->unix_time()) {
    return Status::Error(400, "Giveaway date is in the past");
  }
  for (auto &country_code : parameters->country_codes_) {
    if (country_code.size() != 2 || country_code[0] < 'A' || country_code[0] > 'Z') {
      return Status::Error(400, "Invalid country code specified");
    }
  }
  if (static_cast<int64>(parameters->country_codes_.size()) >
      td->option_manager_->get_option_integer("giveaway_country_count_max")) {
    return Status::Error(400, "Too many countries specified");
  }
  auto prize_description = parameters->prize_description_;
  if (!clean_input_string(prize_description)) {
    return Status::Error(400, "Strings must be encoded in UTF-8");
  }
  return GiveawayParameters(boosted_channel_id, std::move(additional_channel_ids), parameters->only_new_members_,
                            parameters->has_public_winners_, parameters->winners_selection_date_,
                            vector<string>(parameters->country_codes_), std::move(prize_description));
}

vector<ChannelId> GiveawayParameters::get_channel_ids() const {
  auto result = additional_channel_ids_;
  result.push_back(boosted_channel_id_);
  return result;
}

void GiveawayParameters::add_dependencies(Dependencies &dependencies) const {
  dependencies.add_dialog_and_dependencies(DialogId(boosted_channel_id_));
  for (auto channel_id : additional_channel_ids_) {
    dependencies.add_dialog_and_dependencies(DialogId(channel_id));
  }
}

telegram_api::object_ptr<telegram_api::inputStorePaymentPremiumGiveaway>
GiveawayParameters::get_input_store_payment_premium_giveaway(Td *td, const string &currency, int64 amount) const {
  int64 random_id;
  do {
    random_id = Random::secure_int64();
  } while (random_id == 0);

  auto boost_input_peer = td->dialog_manager_->get_input_peer(DialogId(boosted_channel_id_), AccessRights::Write);
  CHECK(boost_input_peer != nullptr);

  vector<telegram_api::object_ptr<telegram_api::InputPeer>> additional_input_peers;
  for (auto additional_channel_id : additional_channel_ids_) {
    auto input_peer = td->dialog_manager_->get_input_peer(DialogId(additional_channel_id), AccessRights::Write);
    CHECK(input_peer != nullptr);
    additional_input_peers.push_back(std::move(input_peer));
  }

  int32 flags = 0;
  if (only_new_subscribers_) {
    flags |= telegram_api::inputStorePaymentPremiumGiveaway::ONLY_NEW_SUBSCRIBERS_MASK;
  }
  if (winners_are_visible_) {
    flags |= telegram_api::inputStorePaymentPremiumGiveaway::WINNERS_ARE_VISIBLE_MASK;
  }
  if (!additional_input_peers.empty()) {
    flags |= telegram_api::inputStorePaymentPremiumGiveaway::ADDITIONAL_PEERS_MASK;
  }
  if (!country_codes_.empty()) {
    flags |= telegram_api::inputStorePaymentPremiumGiveaway::COUNTRIES_ISO2_MASK;
  }
  if (!prize_description_.empty()) {
    flags |= telegram_api::inputStorePaymentPremiumGiveaway::PRIZE_DESCRIPTION_MASK;
  }
  return telegram_api::make_object<telegram_api::inputStorePaymentPremiumGiveaway>(
      flags, false /*ignored*/, false /*ignored*/, std::move(boost_input_peer), std::move(additional_input_peers),
      vector<string>(country_codes_), prize_description_, random_id, date_, currency, amount);
}

telegram_api::object_ptr<telegram_api::inputStorePaymentStarsGiveaway>
GiveawayParameters::get_input_store_payment_stars_giveaway(Td *td, const string &currency, int64 amount,
                                                           int32 user_count, int64 star_count) const {
  int64 random_id;
  do {
    random_id = Random::secure_int64();
  } while (random_id == 0);

  auto boost_input_peer = td->dialog_manager_->get_input_peer(DialogId(boosted_channel_id_), AccessRights::Write);
  CHECK(boost_input_peer != nullptr);

  vector<telegram_api::object_ptr<telegram_api::InputPeer>> additional_input_peers;
  for (auto additional_channel_id : additional_channel_ids_) {
    auto input_peer = td->dialog_manager_->get_input_peer(DialogId(additional_channel_id), AccessRights::Write);
    CHECK(input_peer != nullptr);
    additional_input_peers.push_back(std::move(input_peer));
  }

  int32 flags = 0;
  if (only_new_subscribers_) {
    flags |= telegram_api::inputStorePaymentStarsGiveaway::ONLY_NEW_SUBSCRIBERS_MASK;
  }
  if (winners_are_visible_) {
    flags |= telegram_api::inputStorePaymentStarsGiveaway::WINNERS_ARE_VISIBLE_MASK;
  }
  if (!additional_input_peers.empty()) {
    flags |= telegram_api::inputStorePaymentStarsGiveaway::ADDITIONAL_PEERS_MASK;
  }
  if (!country_codes_.empty()) {
    flags |= telegram_api::inputStorePaymentStarsGiveaway::COUNTRIES_ISO2_MASK;
  }
  if (!prize_description_.empty()) {
    flags |= telegram_api::inputStorePaymentStarsGiveaway::PRIZE_DESCRIPTION_MASK;
  }
  return telegram_api::make_object<telegram_api::inputStorePaymentStarsGiveaway>(
      flags, false /*ignored*/, false /*ignored*/, star_count, std::move(boost_input_peer),
      std::move(additional_input_peers), vector<string>(country_codes_), prize_description_, random_id, date_, currency,
      amount, user_count);
}

td_api::object_ptr<td_api::giveawayParameters> GiveawayParameters::get_giveaway_parameters_object(Td *td) const {
  CHECK(is_valid());
  vector<int64> chat_ids;
  for (auto channel_id : additional_channel_ids_) {
    DialogId dialog_id(channel_id);
    td->dialog_manager_->force_create_dialog(dialog_id, "giveawayParameters", true);
    chat_ids.push_back(td->dialog_manager_->get_chat_id_object(dialog_id, "giveawayParameters"));
  }
  DialogId dialog_id(boosted_channel_id_);
  td->dialog_manager_->force_create_dialog(dialog_id, "giveawayParameters", true);
  return td_api::make_object<td_api::giveawayParameters>(
      td->dialog_manager_->get_chat_id_object(dialog_id, "giveawayParameters"), std::move(chat_ids), date_,
      only_new_subscribers_, winners_are_visible_, vector<string>(country_codes_), prize_description_);
}

bool operator==(const GiveawayParameters &lhs, const GiveawayParameters &rhs) {
  return lhs.boosted_channel_id_ == rhs.boosted_channel_id_ &&
         lhs.additional_channel_ids_ == rhs.additional_channel_ids_ &&
         lhs.only_new_subscribers_ == rhs.only_new_subscribers_ &&
         lhs.winners_are_visible_ == rhs.winners_are_visible_ && lhs.date_ == rhs.date_ &&
         lhs.country_codes_ == rhs.country_codes_ && lhs.prize_description_ == rhs.prize_description_;
}

bool operator!=(const GiveawayParameters &lhs, const GiveawayParameters &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const GiveawayParameters &giveaway_parameters) {
  return string_builder << "Giveaway[" << giveaway_parameters.boosted_channel_id_ << " + "
                        << giveaway_parameters.additional_channel_ids_
                        << (giveaway_parameters.only_new_subscribers_ ? " only for new members" : "")
                        << (giveaway_parameters.winners_are_visible_ ? " with public list of winners" : "")
                        << " for countries " << giveaway_parameters.country_codes_ << " at "
                        << giveaway_parameters.date_ << ']';
}

}  // namespace td
