//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageOrigin.h"

#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatManager.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Global.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserManager.h"

#include "td/utils/logging.h"
#include "td/utils/misc.h"

namespace td {

Result<MessageOrigin> MessageOrigin::get_message_origin(
    Td *td, telegram_api::object_ptr<telegram_api::messageFwdHeader> &&forward_header) {
  CHECK(forward_header != nullptr);
  DialogId sender_dialog_id;
  if (forward_header->from_id_ != nullptr) {
    sender_dialog_id = DialogId(forward_header->from_id_);
    if (!sender_dialog_id.is_valid()) {
      LOG(ERROR) << "Receive invalid sender identifier in message forward header: "
                 << oneline(to_string(forward_header));
      sender_dialog_id = DialogId();
    }
  }

  MessageId message_id;
  if (forward_header->channel_post_ != 0) {
    message_id = MessageId(ServerMessageId(forward_header->channel_post_));
    if (!message_id.is_valid()) {
      LOG(ERROR) << "Receive " << message_id << " in message forward header: " << oneline(to_string(forward_header));
      message_id = MessageId();
    }
  }

  string author_signature = std::move(forward_header->post_author_);
  string sender_name = std::move(forward_header->from_name_);

  UserId sender_user_id;
  if (sender_dialog_id.get_type() == DialogType::User) {
    sender_user_id = sender_dialog_id.get_user_id();
    sender_dialog_id = DialogId();
  }
  if (!sender_dialog_id.is_valid()) {
    if (sender_user_id.is_valid()) {
      if (message_id.is_valid()) {
        LOG(ERROR) << "Receive non-empty message identifier in message forward header: "
                   << oneline(to_string(forward_header));
        message_id = MessageId();
      }
    } else if (sender_name.empty()) {
      LOG(ERROR) << "Receive wrong message forward header: " << oneline(to_string(forward_header));
      return Status::Error("Receive empty forward header");
    }
  } else if (sender_dialog_id.get_type() != DialogType::Channel) {
    LOG(ERROR) << "Receive wrong message forward header with non-channel sender: "
               << oneline(to_string(forward_header));
    return Status::Error("Forward from a non-channel");
  } else {
    auto channel_id = sender_dialog_id.get_channel_id();
    if (!td->chat_manager_->have_channel(channel_id)) {
      LOG(ERROR) << "Receive forward from " << (td->chat_manager_->have_min_channel(channel_id) ? "min" : "unknown")
                 << ' ' << channel_id;
    }
    td->dialog_manager_->force_create_dialog(sender_dialog_id, "get_message_origin", true);
    CHECK(!sender_user_id.is_valid());
  }

  return MessageOrigin{sender_user_id, sender_dialog_id, message_id, std::move(author_signature),
                       std::move(sender_name)};
}

td_api::object_ptr<td_api::MessageOrigin> MessageOrigin::get_message_origin_object(const Td *td) const {
  if (is_sender_hidden()) {
    return td_api::make_object<td_api::messageOriginHiddenUser>(sender_name_.empty() ? author_signature_
                                                                                     : sender_name_);
  }
  if (message_id_.is_valid()) {
    return td_api::make_object<td_api::messageOriginChannel>(
        td->dialog_manager_->get_chat_id_object(sender_dialog_id_, "messageOriginChannel"), message_id_.get(),
        author_signature_);
  }
  if (sender_dialog_id_.is_valid()) {
    return td_api::make_object<td_api::messageOriginChat>(
        td->dialog_manager_->get_chat_id_object(sender_dialog_id_, "messageOriginChat"),
        sender_name_.empty() ? author_signature_ : sender_name_);
  }
  return td_api::make_object<td_api::messageOriginUser>(
      td->user_manager_->get_user_id_object(sender_user_id_, "messageOriginUser"));
}

bool MessageOrigin::is_sender_hidden() const {
  if (!sender_name_.empty()) {
    return true;
  }
  DialogId hidden_sender_dialog_id(ChannelId(static_cast<int64>(G()->is_test_dc() ? 10460537 : 1228946795)));
  return sender_dialog_id_ == hidden_sender_dialog_id && !author_signature_.empty() && !message_id_.is_valid();
}

MessageFullId MessageOrigin::get_message_full_id() const {
  if (!message_id_.is_valid() || !sender_dialog_id_.is_valid() || is_sender_hidden()) {
    return MessageFullId();
  }
  return {sender_dialog_id_, message_id_};
}

DialogId MessageOrigin::get_sender() const {
  if (is_sender_hidden()) {
    return DialogId();
  }
  return message_id_.is_valid() || sender_dialog_id_.is_valid() ? sender_dialog_id_ : DialogId(sender_user_id_);
}

void MessageOrigin::hide_sender_if_needed(Td *td) {
  if (!is_sender_hidden() && !message_id_.is_valid() && !sender_dialog_id_.is_valid()) {
    auto private_forward_name = td->user_manager_->get_user_private_forward_name(sender_user_id_);
    if (!private_forward_name.empty()) {
      sender_user_id_ = UserId();
      sender_name_ = std::move(private_forward_name);
    }
  }
}

void MessageOrigin::add_dependencies(Dependencies &dependencies) const {
  dependencies.add(sender_user_id_);
  dependencies.add_dialog_and_dependencies(sender_dialog_id_);
}

void MessageOrigin::add_user_ids(vector<UserId> &user_ids) const {
  if (sender_user_id_.is_valid()) {
    user_ids.push_back(sender_user_id_);
  }
}

void MessageOrigin::add_channel_ids(vector<ChannelId> &channel_ids) const {
  if (sender_dialog_id_.get_type() == DialogType::Channel) {
    channel_ids.push_back(sender_dialog_id_.get_channel_id());
  }
}

bool operator==(const MessageOrigin &lhs, const MessageOrigin &rhs) {
  return lhs.sender_user_id_ == rhs.sender_user_id_ && lhs.sender_dialog_id_ == rhs.sender_dialog_id_ &&
         lhs.message_id_ == rhs.message_id_ && lhs.author_signature_ == rhs.author_signature_ &&
         lhs.sender_name_ == rhs.sender_name_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageOrigin &origin) {
  string_builder << "sender " << origin.sender_user_id_;
  if (!origin.author_signature_.empty() || !origin.sender_name_.empty()) {
    string_builder << '(' << origin.author_signature_ << '/' << origin.sender_name_ << ')';
  }
  if (origin.sender_dialog_id_.is_valid()) {
    string_builder << ", source ";
    if (origin.message_id_.is_valid()) {
      string_builder << MessageFullId(origin.sender_dialog_id_, origin.message_id_);
    } else {
      string_builder << origin.sender_dialog_id_;
    }
  }
  return string_builder;
}

}  // namespace td
