//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/RequestedDialogType.h"

#include "td/telegram/ChannelType.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserManager.h"

namespace td {

RequestedDialogType::RequestedDialogType(td_api::object_ptr<td_api::keyboardButtonTypeRequestUsers> &&request_users) {
  CHECK(request_users != nullptr);
  type_ = Type::User;
  button_id_ = request_users->id_;
  max_quantity_ = max(request_users->max_quantity_, 1);
  restrict_is_bot_ = request_users->restrict_user_is_bot_;
  is_bot_ = request_users->user_is_bot_;
  restrict_is_premium_ = request_users->restrict_user_is_premium_;
  is_premium_ = request_users->user_is_premium_;
  request_name_ = request_users->request_name_;
  request_username_ = request_users->request_username_;
  request_photo_ = request_users->request_photo_;
}

RequestedDialogType::RequestedDialogType(td_api::object_ptr<td_api::keyboardButtonTypeRequestChat> &&request_dialog) {
  CHECK(request_dialog != nullptr);
  type_ = request_dialog->chat_is_channel_ ? Type::Channel : Type::Group;
  button_id_ = request_dialog->id_;
  restrict_is_forum_ = request_dialog->restrict_chat_is_forum_;
  is_forum_ = request_dialog->chat_is_forum_;
  bot_is_participant_ = request_dialog->bot_is_member_;
  restrict_has_username_ = request_dialog->restrict_chat_has_username_;
  has_username_ = request_dialog->chat_has_username_;
  is_created_ = request_dialog->chat_is_created_;
  restrict_user_administrator_rights_ = request_dialog->user_administrator_rights_ != nullptr;
  restrict_bot_administrator_rights_ = request_dialog->bot_administrator_rights_ != nullptr;
  auto channel_type = request_dialog->chat_is_channel_ ? ChannelType::Broadcast : ChannelType::Megagroup;
  user_administrator_rights_ = AdministratorRights(request_dialog->user_administrator_rights_, channel_type);
  bot_administrator_rights_ = AdministratorRights(request_dialog->bot_administrator_rights_, channel_type);
  request_name_ = request_dialog->request_title_;
  request_username_ = request_dialog->request_username_;
  request_photo_ = request_dialog->request_photo_;
}

RequestedDialogType::RequestedDialogType(telegram_api::object_ptr<telegram_api::RequestPeerType> &&peer_type,
                                         int32 button_id, int32 max_quantity) {
  CHECK(peer_type != nullptr);
  button_id_ = button_id;
  max_quantity_ = max(max_quantity, 1);
  switch (peer_type->get_id()) {
    case telegram_api::requestPeerTypeUser::ID: {
      auto type = telegram_api::move_object_as<telegram_api::requestPeerTypeUser>(peer_type);
      type_ = Type::User;
      restrict_is_bot_ = (type->flags_ & telegram_api::requestPeerTypeUser::BOT_MASK) != 0;
      is_bot_ = type->bot_;
      restrict_is_premium_ = (type->flags_ & telegram_api::requestPeerTypeUser::PREMIUM_MASK) != 0;
      is_premium_ = type->premium_;
      break;
    }
    case telegram_api::requestPeerTypeChat::ID: {
      auto type = telegram_api::move_object_as<telegram_api::requestPeerTypeChat>(peer_type);
      type_ = Type::Group;
      restrict_is_forum_ = (type->flags_ & telegram_api::requestPeerTypeChat::FORUM_MASK) != 0;
      is_forum_ = type->forum_;
      bot_is_participant_ = type->bot_participant_;
      restrict_has_username_ = (type->flags_ & telegram_api::requestPeerTypeChat::HAS_USERNAME_MASK) != 0;
      has_username_ = type->has_username_;
      is_created_ = type->creator_;
      restrict_user_administrator_rights_ = !is_created_ && type->user_admin_rights_ != nullptr;
      restrict_bot_administrator_rights_ = type->bot_admin_rights_ != nullptr;
      user_administrator_rights_ = AdministratorRights(type->user_admin_rights_, ChannelType::Megagroup);
      bot_administrator_rights_ = AdministratorRights(type->bot_admin_rights_, ChannelType::Megagroup);
      break;
    }
    case telegram_api::requestPeerTypeBroadcast::ID: {
      auto type = telegram_api::move_object_as<telegram_api::requestPeerTypeBroadcast>(peer_type);
      type_ = Type::Channel;
      restrict_has_username_ = (type->flags_ & telegram_api::requestPeerTypeBroadcast::HAS_USERNAME_MASK) != 0;
      has_username_ = type->has_username_;
      is_created_ = type->creator_;
      restrict_user_administrator_rights_ = !is_created_ && type->user_admin_rights_ != nullptr;
      restrict_bot_administrator_rights_ = type->bot_admin_rights_ != nullptr;
      user_administrator_rights_ = AdministratorRights(type->user_admin_rights_, ChannelType::Broadcast);
      bot_administrator_rights_ = AdministratorRights(type->bot_admin_rights_, ChannelType::Broadcast);
      break;
    }
    default:
      UNREACHABLE();
  }
}

td_api::object_ptr<td_api::KeyboardButtonType> RequestedDialogType::get_keyboard_button_type_object() const {
  if (type_ == Type::User) {
    return td_api::make_object<td_api::keyboardButtonTypeRequestUsers>(
        button_id_, restrict_is_bot_, is_bot_, restrict_is_premium_, is_premium_, max_quantity_, request_name_,
        request_username_, request_photo_);
  } else {
    auto user_administrator_rights = restrict_user_administrator_rights_
                                         ? user_administrator_rights_.get_chat_administrator_rights_object()
                                         : nullptr;
    auto bot_administrator_rights =
        restrict_bot_administrator_rights_ ? bot_administrator_rights_.get_chat_administrator_rights_object() : nullptr;
    return td_api::make_object<td_api::keyboardButtonTypeRequestChat>(
        button_id_, type_ == Type::Channel, restrict_is_forum_, is_forum_, restrict_has_username_, has_username_,
        is_created_, std::move(user_administrator_rights), std::move(bot_administrator_rights), bot_is_participant_,
        request_name_, request_username_, request_photo_);
  }
}

telegram_api::object_ptr<telegram_api::RequestPeerType> RequestedDialogType::get_input_request_peer_type_object()
    const {
  switch (type_) {
    case Type::User: {
      int32 flags = 0;
      if (restrict_is_bot_) {
        flags |= telegram_api::requestPeerTypeUser::BOT_MASK;
      }
      if (restrict_is_premium_) {
        flags |= telegram_api::requestPeerTypeUser::PREMIUM_MASK;
      }
      return telegram_api::make_object<telegram_api::requestPeerTypeUser>(flags, is_bot_, is_premium_);
    }
    case Type::Group: {
      int32 flags = 0;
      if (restrict_is_forum_) {
        flags |= telegram_api::requestPeerTypeChat::FORUM_MASK;
      }
      if (bot_is_participant_) {
        flags |= telegram_api::requestPeerTypeChat::BOT_PARTICIPANT_MASK;
      }
      if (restrict_has_username_) {
        flags |= telegram_api::requestPeerTypeChat::HAS_USERNAME_MASK;
      }
      if (is_created_) {
        flags |= telegram_api::requestPeerTypeChat::CREATOR_MASK;
      }
      if (restrict_user_administrator_rights_) {
        flags |= telegram_api::requestPeerTypeChat::USER_ADMIN_RIGHTS_MASK;
      }
      if (restrict_bot_administrator_rights_) {
        flags |= telegram_api::requestPeerTypeChat::BOT_ADMIN_RIGHTS_MASK;
      }
      auto user_admin_rights =
          restrict_user_administrator_rights_ ? user_administrator_rights_.get_chat_admin_rights() : nullptr;
      auto bot_admin_rights =
          restrict_bot_administrator_rights_ ? bot_administrator_rights_.get_chat_admin_rights() : nullptr;
      return telegram_api::make_object<telegram_api::requestPeerTypeChat>(
          flags, false /*ignored*/, false /*ignored*/, has_username_, is_forum_, std::move(user_admin_rights),
          std::move(bot_admin_rights));
    }
    case Type::Channel: {
      int32 flags = 0;
      if (restrict_has_username_) {
        flags |= telegram_api::requestPeerTypeBroadcast::HAS_USERNAME_MASK;
      }
      if (is_created_) {
        flags |= telegram_api::requestPeerTypeBroadcast::CREATOR_MASK;
      }
      if (restrict_user_administrator_rights_) {
        flags |= telegram_api::requestPeerTypeBroadcast::USER_ADMIN_RIGHTS_MASK;
      }
      if (restrict_bot_administrator_rights_) {
        flags |= telegram_api::requestPeerTypeBroadcast::BOT_ADMIN_RIGHTS_MASK;
      }
      auto user_admin_rights =
          restrict_user_administrator_rights_ ? user_administrator_rights_.get_chat_admin_rights() : nullptr;
      auto bot_admin_rights =
          restrict_bot_administrator_rights_ ? bot_administrator_rights_.get_chat_admin_rights() : nullptr;
      return telegram_api::make_object<telegram_api::requestPeerTypeBroadcast>(
          flags, false /*ignored*/, has_username_, std::move(user_admin_rights), std::move(bot_admin_rights));
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

telegram_api::object_ptr<telegram_api::inputKeyboardButtonRequestPeer>
RequestedDialogType::get_input_keyboard_button_request_peer(const string &text) const {
  int32 flags = 0;
  if (request_name_) {
    flags |= telegram_api::inputKeyboardButtonRequestPeer::NAME_REQUESTED_MASK;
  }
  if (request_username_) {
    flags |= telegram_api::inputKeyboardButtonRequestPeer::USERNAME_REQUESTED_MASK;
  }
  if (request_photo_) {
    flags |= telegram_api::inputKeyboardButtonRequestPeer::PHOTO_REQUESTED_MASK;
  }
  return telegram_api::make_object<telegram_api::inputKeyboardButtonRequestPeer>(
      flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, text, button_id_,
      get_input_request_peer_type_object(), max_quantity_);
}

int32 RequestedDialogType::get_button_id() const {
  return button_id_;
}

Status RequestedDialogType::check_shared_dialog(Td *td, DialogId dialog_id) const {
  switch (dialog_id.get_type()) {
    case DialogType::User: {
      if (type_ != Type::User) {
        return Status::Error(400, "Wrong chat type");
      }
      auto user_id = dialog_id.get_user_id();
      if (restrict_is_bot_ && td->user_manager_->is_user_bot(user_id) != is_bot_) {
        return Status::Error(400, "Wrong is_bot value");
      }
      if (restrict_is_premium_ && td->user_manager_->is_user_premium(user_id) != is_premium_) {
        return Status::Error(400, "Wrong is_premium value");
      }
      break;
    }
    case DialogType::Chat: {
      if (type_ != Type::Group) {
        return Status::Error(400, "Wrong chat type");
      }
      if (restrict_is_forum_ && is_forum_) {
        return Status::Error(400, "Wrong is_forum value");
      }
      if (restrict_has_username_ && has_username_) {
        return Status::Error(400, "Wrong has_username value");
      }
      auto chat_id = dialog_id.get_chat_id();
      if (!td->chat_manager_->get_chat_is_active(chat_id)) {
        return Status::Error(400, "Chat is deactivated");
      }
      auto status = td->chat_manager_->get_chat_status(chat_id);
      if (is_created_ && !status.is_creator()) {
        return Status::Error(400, "The chat must be created by the current user");
      }
      if (bot_is_participant_) {
        // can't check that the bot is already participant, so check that the user can add it instead
        if (!status.can_invite_users()) {
          return Status::Error(400, "The bot can't be added to the chat");
        }
      }
      if (restrict_user_administrator_rights_ && !status.has_all_administrator_rights(user_administrator_rights_)) {
        return Status::Error(400, "Not enough rights in the chat");
      }
      if (restrict_bot_administrator_rights_) {
        // can't check that the bot is already an administrator, so check that the user can promote it instead
        if (!status.can_invite_users() || !status.can_promote_members()) {
          return Status::Error(400, "The bot can't be promoted in the chat");
        }
      }
      break;
    }
    case DialogType::Channel: {
      auto channel_id = dialog_id.get_channel_id();
      bool is_broadcast = td->chat_manager_->is_broadcast_channel(channel_id);
      if (type_ != (is_broadcast ? Type::Channel : Type::Group)) {
        return Status::Error(400, "Wrong chat type");
      }
      if (!is_broadcast && restrict_is_forum_ && td->chat_manager_->is_forum_channel(channel_id) != is_forum_) {
        return Status::Error(400, "Wrong is_forum value");
      }
      if (restrict_has_username_ &&
          td->chat_manager_->get_channel_first_username(channel_id).empty() == has_username_) {
        return Status::Error(400, "Wrong has_username value");
      }
      auto status = td->chat_manager_->get_channel_status(channel_id);
      if (is_created_ && !status.is_creator()) {
        return Status::Error(400, "The chat must be created by the current user");
      }
      bool can_invite_bot =
          status.can_invite_users() && (status.is_administrator() || !td->chat_manager_->is_channel_public(channel_id));
      if (!is_broadcast && bot_is_participant_) {
        // can't synchronously check that the bot is already participant
        if (!can_invite_bot) {
          // return Status::Error(400, "The bot can't be added to the chat");
        }
      }
      if (restrict_user_administrator_rights_ && !status.has_all_administrator_rights(user_administrator_rights_)) {
        return Status::Error(400, "Not enough rights in the chat");
      }
      if (restrict_bot_administrator_rights_) {
        // can't synchronously check that the bot is already an administrator
        if (!can_invite_bot || !status.can_promote_members()) {
          // return Status::Error(400, "The bot can't be promoted in the chat");
        }
      }
      break;
    }
    case DialogType::SecretChat:
      return Status::Error(400, "Can't share secret chats");
    case DialogType::None:
      UNREACHABLE();
  }
  return Status::OK();
}

Status RequestedDialogType::check_shared_dialog_count(size_t count) const {
  if (count == 0) {
    return Status::Error(400, "Too few chats are chosen");
  }
  if (count > static_cast<size_t>(max_quantity_)) {
    return Status::Error(400, "Too many chats are chosen");
  }
  return Status::OK();
}

}  // namespace td
