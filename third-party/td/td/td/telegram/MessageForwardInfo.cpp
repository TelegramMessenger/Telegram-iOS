//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageForwardInfo.h"

#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserManager.h"

#include "td/utils/logging.h"
#include "td/utils/misc.h"

namespace td {

bool LastForwardedMessageInfo::is_empty() const {
  return *this == LastForwardedMessageInfo();
}

void LastForwardedMessageInfo::validate() {
  if (dialog_id_.is_valid() != message_id_.is_valid() ||
      (sender_dialog_id_ != DialogId() && !sender_dialog_id_.is_valid()) ||
      ((sender_dialog_id_ != DialogId() || !sender_name_.empty()) && date_ <= 0)) {
    *this = {};
  }
}

void LastForwardedMessageInfo::hide_sender_if_needed(Td *td) {
  if (sender_name_.empty() && sender_dialog_id_.get_type() == DialogType::User) {
    auto private_forward_name = td->user_manager_->get_user_private_forward_name(sender_dialog_id_.get_user_id());
    if (!private_forward_name.empty()) {
      dialog_id_ = DialogId();
      message_id_ = MessageId();
      sender_dialog_id_ = DialogId();
      sender_name_ = std::move(private_forward_name);
    }
  }
}

void LastForwardedMessageInfo::add_dependencies(Dependencies &dependencies) const {
  dependencies.add_dialog_and_dependencies(dialog_id_);
  dependencies.add_message_sender_dependencies(sender_dialog_id_);
}

void LastForwardedMessageInfo::add_min_user_ids(vector<UserId> &user_ids) const {
  if (dialog_id_.get_type() == DialogType::User) {
    user_ids.push_back(dialog_id_.get_user_id());
  }
  if (sender_dialog_id_.get_type() == DialogType::User) {
    user_ids.push_back(sender_dialog_id_.get_user_id());
  }
}

void LastForwardedMessageInfo::add_min_channel_ids(vector<ChannelId> &channel_ids) const {
  if (dialog_id_.get_type() == DialogType::Channel) {
    channel_ids.push_back(dialog_id_.get_channel_id());
  }
  if (sender_dialog_id_.get_type() == DialogType::Channel) {
    channel_ids.push_back(sender_dialog_id_.get_channel_id());
  }
}

td_api::object_ptr<td_api::forwardSource> LastForwardedMessageInfo::get_forward_source_object(
    Td *td, bool for_saved_messages, const MessageOrigin &origin, int32 origin_date) const {
  if (is_empty() && (origin.is_empty() || !for_saved_messages)) {
    return nullptr;
  }
  td_api::object_ptr<td_api::MessageSender> sender_id;
  if (date_ == 0 && for_saved_messages) {
    auto sender_dialog_id = origin.get_sender();
    if (sender_dialog_id.is_valid()) {
      sender_id = get_message_sender_object_const(td, sender_dialog_id, "origin.forwardSource.sender_id");
    }
    return td_api::make_object<td_api::forwardSource>(
        td->dialog_manager_->get_chat_id_object(dialog_id_, "forwardSource.chat_id"), message_id_.get(),
        std::move(sender_id), origin.get_sender_name(), origin_date,
        is_outgoing_ || sender_dialog_id == td->dialog_manager_->get_my_dialog_id());
  }

  if (sender_dialog_id_ != DialogId()) {
    sender_id = get_message_sender_object_const(td, sender_dialog_id_, "forwardSource.sender_id");
  }
  return td_api::make_object<td_api::forwardSource>(
      td->dialog_manager_->get_chat_id_object(dialog_id_, "forwardSource.chat_id"), message_id_.get(),
      std::move(sender_id), sender_name_, date_,
      is_outgoing_ || sender_dialog_id_ == td->dialog_manager_->get_my_dialog_id());
}

bool operator==(const LastForwardedMessageInfo &lhs, const LastForwardedMessageInfo &rhs) {
  return lhs.dialog_id_ == rhs.dialog_id_ && lhs.message_id_ == rhs.message_id_ &&
         lhs.sender_dialog_id_ == rhs.sender_dialog_id_ && lhs.sender_name_ == rhs.sender_name_ &&
         lhs.date_ == rhs.date_ && lhs.is_outgoing_ == rhs.is_outgoing_;
}

bool operator!=(const LastForwardedMessageInfo &lhs, const LastForwardedMessageInfo &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const LastForwardedMessageInfo &last_message_info) {
  if (!last_message_info.is_empty()) {
    string_builder << "last";
    if (last_message_info.dialog_id_ != DialogId()) {
      string_builder << " forwarded from "
                     << MessageFullId(last_message_info.dialog_id_, last_message_info.message_id_);
    }
    if (last_message_info.sender_dialog_id_ != DialogId() || !last_message_info.sender_name_.empty() ||
        last_message_info.is_outgoing_) {
      string_builder << " sent by";
      if (last_message_info.sender_dialog_id_.is_valid()) {
        string_builder << ' ' << last_message_info.sender_dialog_id_;
      }
      if (!last_message_info.sender_name_.empty()) {
        if (last_message_info.sender_dialog_id_.is_valid()) {
          string_builder << '/';
        } else {
          string_builder << ' ';
        }
        string_builder << '"' << last_message_info.sender_name_ << '"';
      }
      string_builder << (last_message_info.is_outgoing_ ? " (me)" : " (not me)");
    }
    if (last_message_info.date_ != 0) {
      string_builder << " at " << last_message_info.date_;
    }
  }
  return string_builder;
}

unique_ptr<MessageForwardInfo> MessageForwardInfo::get_message_forward_info(
    Td *td, telegram_api::object_ptr<telegram_api::messageFwdHeader> &&forward_header) {
  if (forward_header == nullptr) {
    return nullptr;
  }
  auto date = forward_header->date_;
  if (date <= 0) {
    LOG(ERROR) << "Wrong date in message forward header: " << oneline(to_string(forward_header));
    return nullptr;
  }

  LastForwardedMessageInfo last_message_info;
  if (forward_header->saved_from_peer_ != nullptr || forward_header->saved_from_id_ != nullptr ||
      !forward_header->saved_from_name_.empty()) {
    DialogId from_dialog_id;
    if (forward_header->saved_from_peer_ != nullptr) {
      from_dialog_id = DialogId(forward_header->saved_from_peer_);
    }
    DialogId sender_dialog_id;
    if (forward_header->saved_from_id_ != nullptr) {
      sender_dialog_id = DialogId(forward_header->saved_from_id_);
    }
    last_message_info = LastForwardedMessageInfo(
        from_dialog_id, MessageId(ServerMessageId(forward_header->saved_from_msg_id_)), sender_dialog_id,
        forward_header->saved_from_name_, forward_header->saved_date_,
        forward_header->saved_out_ || sender_dialog_id == td->dialog_manager_->get_my_dialog_id());
    last_message_info.validate();
    if (last_message_info.is_empty()) {
      LOG(ERROR) << "Receive wrong last message in message forward header: " << oneline(to_string(forward_header));
    } else {
      Dependencies dependencies;
      last_message_info.add_dependencies(dependencies);
      for (auto dialog_id : dependencies.get_dialog_ids()) {
        td->dialog_manager_->force_create_dialog(dialog_id, "get_message_forward_info", true);
      }
    }
  }
  bool is_imported = forward_header->imported_;
  auto psa_type = std::move(forward_header->psa_type_);
  auto r_origin = MessageOrigin::get_message_origin(td, std::move(forward_header));
  if (r_origin.is_error()) {
    return nullptr;
  }

  return td::make_unique<MessageForwardInfo>(r_origin.move_as_ok(), date, std::move(last_message_info),
                                             std::move(psa_type), is_imported);
}

unique_ptr<MessageForwardInfo> MessageForwardInfo::copy_message_forward_info(
    Td *td, const MessageForwardInfo &forward_info, LastForwardedMessageInfo &&last_message_info) {
  last_message_info.validate();
  last_message_info.hide_sender_if_needed(td);

  auto result = make_unique<MessageForwardInfo>(forward_info);
  result->last_message_info_ = std::move(last_message_info);
  result->origin_.hide_sender_if_needed(td);
  return result;
}

td_api::object_ptr<td_api::messageForwardInfo> MessageForwardInfo::get_message_forward_info_object(
    Td *td, bool for_saved_messages) const {
  if (is_imported_) {
    return nullptr;
  }
  return td_api::make_object<td_api::messageForwardInfo>(
      origin_.get_message_origin_object(td), date_,
      last_message_info_.get_forward_source_object(td, for_saved_messages, origin_, date_), psa_type_);
}

td_api::object_ptr<td_api::messageImportInfo> MessageForwardInfo::get_message_import_info_object() const {
  if (!is_imported_) {
    return nullptr;
  }
  return td_api::make_object<td_api::messageImportInfo>(origin_.get_sender_name(), date_);
}

void MessageForwardInfo::add_dependencies(Dependencies &dependencies) const {
  origin_.add_dependencies(dependencies);
  last_message_info_.add_dependencies(dependencies);
}

void MessageForwardInfo::add_min_user_ids(vector<UserId> &user_ids) const {
  origin_.add_user_ids(user_ids);
  last_message_info_.add_min_user_ids(user_ids);
}

void MessageForwardInfo::add_min_channel_ids(vector<ChannelId> &channel_ids) const {
  origin_.add_channel_ids(channel_ids);
  last_message_info_.add_min_channel_ids(channel_ids);
}

bool MessageForwardInfo::need_change_warning(const MessageForwardInfo *lhs, const MessageForwardInfo *rhs,
                                             MessageId message_id) {
  // it should be already checked that *lhs != *rhs
  if (lhs == nullptr || rhs == nullptr || lhs->is_imported_ || rhs->is_imported_) {
    return true;
  }
  if (!message_id.is_scheduled() && !message_id.is_yet_unsent()) {
    return true;
  }
  // yet unsent or scheduled messages can change sender name or author signature when being sent
  return !lhs->origin_.has_sender_signature() && !rhs->origin_.has_sender_signature() &&
         !lhs->last_message_info_.has_sender_name() && !rhs->last_message_info_.has_sender_name();
}

bool operator==(const MessageForwardInfo &lhs, const MessageForwardInfo &rhs) {
  return lhs.origin_ == rhs.origin_ && lhs.date_ == rhs.date_ && lhs.last_message_info_ == rhs.last_message_info_ &&
         lhs.psa_type_ == rhs.psa_type_ && lhs.is_imported_ == rhs.is_imported_;
}

bool operator!=(const MessageForwardInfo &lhs, const MessageForwardInfo &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageForwardInfo &forward_info) {
  string_builder << "MessageForwardInfo[" << (forward_info.is_imported_ ? "imported " : "") << forward_info.origin_;
  if (!forward_info.psa_type_.empty()) {
    string_builder << ", psa_type " << forward_info.psa_type_;
  }
  if (!forward_info.last_message_info_.is_empty()) {
    string_builder << ", " << forward_info.last_message_info_;
  }
  return string_builder << " at " << forward_info.date_ << ']';
}

StringBuilder &operator<<(StringBuilder &string_builder, const unique_ptr<MessageForwardInfo> &forward_info) {
  if (forward_info == nullptr) {
    return string_builder << "[null]";
  }
  return string_builder << *forward_info;
}

}  // namespace td
