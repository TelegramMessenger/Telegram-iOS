//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SharedDialog.h"

#include "td/telegram/AuthManager.h"
#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserId.h"
#include "td/telegram/UserManager.h"

namespace td {

SharedDialog::SharedDialog(Td *td, telegram_api::object_ptr<telegram_api::RequestedPeer> &&requested_peer_ptr) {
  CHECK(requested_peer_ptr != nullptr);
  switch (requested_peer_ptr->get_id()) {
    case telegram_api::requestedPeerUser::ID: {
      auto requested_peer = telegram_api::move_object_as<telegram_api::requestedPeerUser>(requested_peer_ptr);
      dialog_id_ = DialogId(UserId(requested_peer->user_id_));
      first_name_ = std::move(requested_peer->first_name_);
      last_name_ = std::move(requested_peer->last_name_);
      username_ = std::move(requested_peer->username_);
      photo_ = get_photo(td, std::move(requested_peer->photo_), dialog_id_);
      break;
    }
    case telegram_api::requestedPeerChat::ID: {
      auto requested_peer = telegram_api::move_object_as<telegram_api::requestedPeerChat>(requested_peer_ptr);
      dialog_id_ = DialogId(ChatId(requested_peer->chat_id_));
      first_name_ = std::move(requested_peer->title_);
      photo_ = get_photo(td, std::move(requested_peer->photo_), dialog_id_);
      break;
    }
    case telegram_api::requestedPeerChannel::ID: {
      auto requested_peer = telegram_api::move_object_as<telegram_api::requestedPeerChannel>(requested_peer_ptr);
      dialog_id_ = DialogId(ChannelId(requested_peer->channel_id_));
      first_name_ = std::move(requested_peer->title_);
      username_ = std::move(requested_peer->username_);
      photo_ = get_photo(td, std::move(requested_peer->photo_), dialog_id_);
      break;
    }
    default:
      UNREACHABLE();
  }
}

td_api::object_ptr<td_api::sharedUser> SharedDialog::get_shared_user_object(Td *td) const {
  CHECK(is_user());
  auto user_id = td->auth_manager_->is_bot()
                     ? dialog_id_.get_user_id().get()
                     : td->user_manager_->get_user_id_object(dialog_id_.get_user_id(), "sharedUser");
  return td_api::make_object<td_api::sharedUser>(user_id, first_name_, last_name_, username_,
                                                 get_photo_object(td->file_manager_.get(), photo_));
}

td_api::object_ptr<td_api::sharedChat> SharedDialog::get_shared_chat_object(Td *td) const {
  CHECK(is_dialog());
  auto chat_id = td->auth_manager_->is_bot() ? dialog_id_.get()
                                             : td->dialog_manager_->get_chat_id_object(dialog_id_, "sharedChat");
  return td_api::make_object<td_api::sharedChat>(chat_id, first_name_, username_,
                                                 get_photo_object(td->file_manager_.get(), photo_));
}

bool operator==(const SharedDialog &lhs, const SharedDialog &rhs) {
  return lhs.dialog_id_ == rhs.dialog_id_ && lhs.first_name_ == rhs.first_name_ && lhs.last_name_ == rhs.last_name_ &&
         lhs.username_ == rhs.username_ && lhs.photo_ == rhs.photo_;
}

bool operator!=(const SharedDialog &lhs, const SharedDialog &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const SharedDialog &shared_dialog) {
  return string_builder << "shared " << shared_dialog.dialog_id_ << '(' << shared_dialog.first_name_ << ' '
                        << shared_dialog.last_name_ << ' ' << shared_dialog.username_ << ' ' << shared_dialog.photo_
                        << ')';
}

}  // namespace td
