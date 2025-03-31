//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/UserStarGift.h"

#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/StarGiftManager.h"
#include "td/telegram/StarManager.h"
#include "td/telegram/Td.h"

#include "td/utils/logging.h"

namespace td {

UserStarGift::UserStarGift(Td *td, telegram_api::object_ptr<telegram_api::savedStarGift> &&gift, DialogId dialog_id)
    : gift_(td, std::move(gift->gift_), true)
    , message_(get_formatted_text(td->user_manager_.get(), std::move(gift->message_), true, false, "userStarGift"))
    , convert_star_count_(StarManager::get_star_count(gift->convert_stars_))
    , upgrade_star_count_(StarManager::get_star_count(gift->upgrade_stars_))
    , transfer_star_count_(StarManager::get_star_count(gift->transfer_stars_))
    , date_(gift->date_)
    , can_export_at_(max(0, gift->can_export_at_))
    , is_name_hidden_(gift->name_hidden_)
    , is_saved_(!gift->unsaved_)
    , is_pinned_(gift->pinned_to_top_)
    , can_upgrade_(gift->can_upgrade_)
    , can_transfer_((gift->flags_ & telegram_api::savedStarGift::TRANSFER_STARS_MASK) != 0)
    , was_refunded_(gift->refunded_) {
  if (gift->from_id_ != nullptr) {
    sender_dialog_id_ = DialogId(gift->from_id_);
    if (!sender_dialog_id_.is_valid()) {
      LOG(ERROR) << "Receive " << sender_dialog_id_ << " as sender of a gift";
      sender_dialog_id_ = DialogId();
    }
  }
  auto is_user = dialog_id.get_type() == DialogType::User;
  auto is_me = is_user && dialog_id == td->dialog_manager_->get_my_dialog_id();
  if (is_user) {
    if (gift->msg_id_ != 0) {
      star_gift_id_ = StarGiftId(ServerMessageId(gift->msg_id_));
    }
  } else {
    if (gift->saved_id_ != 0) {
      star_gift_id_ = StarGiftId(dialog_id, gift->saved_id_);
    }
  }
  if (sender_dialog_id_ != DialogId() && !sender_dialog_id_.is_valid()) {
    LOG(ERROR) << "Receive " << sender_dialog_id_ << " as sender of a gift";
    sender_dialog_id_ = DialogId();
  }
  if (!is_saved_ && is_user && !is_me) {
    LOG(ERROR) << "Receive non-saved gift for another user";
    is_saved_ = true;
  }
  td->star_gift_manager_->on_get_star_gift(gift_, true);
}

td_api::object_ptr<td_api::receivedGift> UserStarGift::get_received_gift_object(Td *td) const {
  return td_api::make_object<td_api::receivedGift>(
      star_gift_id_.get_star_gift_id(),
      sender_dialog_id_ == DialogId() ? nullptr : get_message_sender_object(td, sender_dialog_id_, "receivedGift"),
      get_formatted_text_object(td->user_manager_.get(), message_, true, -1), is_name_hidden_, is_saved_, is_pinned_,
      can_upgrade_, can_transfer_, was_refunded_, date_, gift_.get_sent_gift_object(td), convert_star_count_,
      upgrade_star_count_, transfer_star_count_, can_export_at_);
}

}  // namespace td
