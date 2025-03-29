//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StarSubscription.h"

#include "td/telegram/DialogManager.h"
#include "td/telegram/LinkManager.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/Td.h"

#include "td/utils/logging.h"

namespace td {

StarSubscription::StarSubscription(Td *td, telegram_api::object_ptr<telegram_api::starsSubscription> &&subscription)
    : id_(std::move(subscription->id_))
    , dialog_id_(subscription->peer_)
    , until_date_(subscription->until_date_)
    , can_reuse_(subscription->can_refulfill_)
    , is_canceled_(subscription->canceled_)
    , is_bot_canceled_(subscription->bot_canceled_)
    , missing_balance_(StarManager::get_star_count(subscription->missing_balance_))
    , invite_hash_(std::move(subscription->chat_invite_hash_))
    , title_(std::move(subscription->title_))
    , photo_(get_web_document_photo(td->file_manager_.get(), std::move(subscription->photo_), DialogId()))
    , invoice_slug_(std::move(subscription->invoice_slug_))
    , pricing_(std::move(subscription->pricing_)) {
}

td_api::object_ptr<td_api::starSubscription> StarSubscription::get_star_subscription_object(Td *td) const {
  td->dialog_manager_->force_create_dialog(dialog_id_, "starSubscription", true);
  td_api::object_ptr<td_api::StarSubscriptionType> type;
  switch (dialog_id_.get_type()) {
    case DialogType::User:
      type = td_api::make_object<td_api::starSubscriptionTypeBot>(
          is_bot_canceled_, title_, get_photo_object(td->file_manager_.get(), photo_),
          LinkManager::get_internal_link(td_api::make_object<td_api::internalLinkTypeInvoice>(invoice_slug_), false)
              .move_as_ok());
      break;
    case DialogType::Channel:
      type = td_api::make_object<td_api::starSubscriptionTypeChannel>(
          can_reuse_, LinkManager::get_dialog_invite_link(invite_hash_, false));
      break;
    case DialogType::Chat:
      LOG(ERROR) << "Receive subscription for " << dialog_id_;
      type = td_api::make_object<td_api::starSubscriptionTypeChannel>(false, string());
      break;
    case DialogType::SecretChat:
    default:
      UNREACHABLE();
  }
  return td_api::make_object<td_api::starSubscription>(
      id_, td->dialog_manager_->get_chat_id_object(dialog_id_, "starSubscription"), until_date_, is_canceled_,
      missing_balance_, pricing_.get_star_subscription_pricing_object(), std::move(type));
}

StringBuilder &operator<<(StringBuilder &string_builder, const StarSubscription &subscription) {
  return string_builder << (subscription.is_canceled_ ? "canceled " : "")
                        << (subscription.missing_balance_ ? "expiring " : "") << "subscription " << subscription.id_
                        << " to " << subscription.dialog_id_ << '/' << subscription.invite_hash_ << " until "
                        << subscription.until_date_ << " for " << subscription.pricing_;
}

}  // namespace td
