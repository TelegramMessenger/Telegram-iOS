//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Promise.h"
#include "td/utils/Slice.h"
#include "td/utils/Status.h"

namespace td {

class Td;

Status check_payment_amount(string &currency, int64 amount);

Result<telegram_api::object_ptr<telegram_api::InputPeer>> get_boost_input_peer(Td *td, DialogId dialog_id);

Result<telegram_api::object_ptr<telegram_api::textWithEntities>> get_premium_gift_text(
    Td *td, td_api::object_ptr<td_api::formattedText> &&text);

const vector<Slice> &get_premium_limit_keys();

void get_premium_limit(const td_api::object_ptr<td_api::PremiumLimitType> &limit_type,
                       Promise<td_api::object_ptr<td_api::premiumLimit>> &&promise);

void get_premium_features(Td *td, const td_api::object_ptr<td_api::PremiumSource> &source,
                          Promise<td_api::object_ptr<td_api::premiumFeatures>> &&promise);

void get_business_features(Td *td, const td_api::object_ptr<td_api::BusinessFeature> &source,
                           Promise<td_api::object_ptr<td_api::businessFeatures>> &&promise);

void view_premium_feature(Td *td, const td_api::object_ptr<td_api::PremiumFeature> &feature, Promise<Unit> &&promise);

void click_premium_subscription_button(Td *td, Promise<Unit> &&promise);

void get_premium_state(Td *td, Promise<td_api::object_ptr<td_api::premiumState>> &&promise);

void get_premium_gift_payment_options(Td *td, Promise<td_api::object_ptr<td_api::premiumGiftPaymentOptions>> &&promise);

void get_premium_giveaway_options(Td *td, DialogId boosted_dialog_id,
                                  Promise<td_api::object_ptr<td_api::premiumGiveawayPaymentOptions>> &&promise);

void check_premium_gift_code(Td *td, const string &code,
                             Promise<td_api::object_ptr<td_api::premiumGiftCodeInfo>> &&promise);

void apply_premium_gift_code(Td *td, const string &code, Promise<Unit> &&promise);

void launch_prepaid_premium_giveaway(Td *td, int64 giveaway_id,
                                     td_api::object_ptr<td_api::giveawayParameters> &&parameters, int32 user_count,
                                     int64 star_count, Promise<Unit> &&promise);

void get_premium_giveaway_info(Td *td, MessageFullId message_full_id,
                               Promise<td_api::object_ptr<td_api::GiveawayInfo>> &&promise);

void can_purchase_premium(Td *td, td_api::object_ptr<td_api::StorePaymentPurpose> &&purpose, Promise<Unit> &&promise);

void assign_app_store_transaction(Td *td, const string &receipt,
                                  td_api::object_ptr<td_api::StorePaymentPurpose> &&purpose, Promise<Unit> &&promise);

void assign_play_market_transaction(Td *td, const string &package_name, const string &store_product_id,
                                    const string &purchase_token,
                                    td_api::object_ptr<td_api::StorePaymentPurpose> &&purpose, Promise<Unit> &&promise);

}  // namespace td
