//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/AffiliateType.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"

namespace td {

Result<AffiliateType> AffiliateType::get_affiliate_type(Td *td, const td_api::object_ptr<td_api::AffiliateType> &type) {
  if (type == nullptr) {
    return Status::Error(400, "Affiliate type must be non-empty");
  }
  switch (type->get_id()) {
    case td_api::affiliateTypeCurrentUser::ID:
      return AffiliateType(td->dialog_manager_->get_my_dialog_id());
    case td_api::affiliateTypeBot::ID: {
      UserId user_id(static_cast<const td_api::affiliateTypeBot *>(type.get())->user_id_);
      TRY_RESULT(bot_data, td->user_manager_->get_bot_data(user_id));
      if (!bot_data.can_be_edited) {
        return Status::Error(400, "The bot isn't owned");
      }
      return AffiliateType(DialogId(user_id));
    }
    case td_api::affiliateTypeChannel::ID: {
      DialogId dialog_id(static_cast<const td_api::affiliateTypeChannel *>(type.get())->chat_id_);
      TRY_STATUS(td->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Read, "get_affiliate_type"));
      if (!td->dialog_manager_->is_broadcast_channel(dialog_id)) {
        return Status::Error(400, "The chat must be a channel chat");
      }
      auto channel_id = dialog_id.get_channel_id();
      auto status = td->chat_manager_->get_channel_permissions(channel_id);
      if (!status.can_post_messages()) {
        return Status::Error(400, "Not enough rights in the chat");
      }
      return AffiliateType(dialog_id);
    }
    default:
      UNREACHABLE();
      return Status::Error(500, "Unreachable");
  }
}

telegram_api::object_ptr<telegram_api::InputPeer> AffiliateType::get_input_peer(Td *td) const {
  return td->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
}

td_api::object_ptr<td_api::AffiliateType> AffiliateType::get_affiliate_type_object(Td *td) const {
  switch (dialog_id_.get_type()) {
    case DialogType::User:
      if (td->dialog_manager_->get_my_dialog_id() == dialog_id_) {
        return td_api::make_object<td_api::affiliateTypeCurrentUser>();
      }
      return td_api::make_object<td_api::affiliateTypeBot>(
          td->user_manager_->get_user_id_object(dialog_id_.get_user_id(), "affiliateTypeBot"));
    case DialogType::Channel:
      return td_api::make_object<td_api::affiliateTypeChannel>(
          td->dialog_manager_->get_chat_id_object(dialog_id_, "affiliateTypeChannel"));
    default:
      UNREACHABLE();
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, const AffiliateType &affiliate_type) {
  return string_builder << "affiliate " << affiliate_type.get_dialog_id();
}

}  // namespace td
