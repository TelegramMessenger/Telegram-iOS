//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SavedMessagesTopicId.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/MessageForwardInfo.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

namespace td {

static constexpr DialogId HIDDEN_AUTHOR_DIALOG_ID = DialogId(static_cast<int64>(2666000));

SavedMessagesTopicId::SavedMessagesTopicId(DialogId my_dialog_id, const MessageForwardInfo *message_forward_info,
                                           DialogId real_forward_from_dialog_id) {
  if (message_forward_info != nullptr) {
    auto last_dialog_id = message_forward_info->get_last_dialog_id();
    if (last_dialog_id.is_valid()) {
      dialog_id_ = last_dialog_id;
      return;
    }
    if (real_forward_from_dialog_id != DialogId() && message_forward_info->has_last_sender_name()) {
      if (real_forward_from_dialog_id.get_type() == DialogType::User) {
        dialog_id_ = HIDDEN_AUTHOR_DIALOG_ID;
      } else {
        dialog_id_ = real_forward_from_dialog_id;
      }
      return;
    }
    auto from_dialog_id = message_forward_info->get_origin().get_sender();
    if (from_dialog_id.is_valid()) {
      dialog_id_ = my_dialog_id;
      return;
    }
    if (message_forward_info->get_origin().is_sender_hidden()) {
      dialog_id_ = HIDDEN_AUTHOR_DIALOG_ID;
      return;
    }
  }
  dialog_id_ = my_dialog_id;
}

td_api::object_ptr<td_api::SavedMessagesTopicType> SavedMessagesTopicId::get_saved_messages_topic_type_object(
    const Td *td) const {
  if (dialog_id_ == DialogId()) {
    return nullptr;
  }
  if (dialog_id_ == td->dialog_manager_->get_my_dialog_id()) {
    return td_api::make_object<td_api::savedMessagesTopicTypeMyNotes>();
  }
  if (is_author_hidden()) {
    td->user_manager_->get_user_id_object(HIDDEN_AUTHOR_DIALOG_ID.get_user_id(), "savedMessagesTopicTypeAuthorHidden");
    return td_api::make_object<td_api::savedMessagesTopicTypeAuthorHidden>();
  }
  return td_api::make_object<td_api::savedMessagesTopicTypeSavedFromChat>(
      td->dialog_manager_->get_chat_id_object(dialog_id_, "savedMessagesTopicTypeSavedFromChat"));
}

bool SavedMessagesTopicId::have_input_peer(Td *td) const {
  if (dialog_id_.get_type() == DialogType::SecretChat ||
      !td->dialog_manager_->have_dialog_info_force(dialog_id_, "SavedMessagesTopicId::have_input_peer")) {
    return false;
  }
  return td->dialog_manager_->have_input_peer(dialog_id_, false, AccessRights::Know);
}

Status SavedMessagesTopicId::is_valid_status(Td *td) const {
  if (!dialog_id_.is_valid()) {
    return Status::Error(400, "Invalid Saved Messages topic specified");
  }
  if (!have_input_peer(td)) {
    return Status::Error(400, "Unknown Saved Messages topic specified");
  }
  return Status::OK();
}

Status SavedMessagesTopicId::is_valid_in(Td *td, DialogId dialog_id) const {
  if (dialog_id_ != DialogId()) {
    if (dialog_id != td->dialog_manager_->get_my_dialog_id()) {
      return Status::Error(400, "Can't use Saved Messages topic in the chat");
    }
    if (!have_input_peer(td)) {
      return Status::Error(400, "Unknown Saved Messages topic specified");
    }
  }
  return Status::OK();
}

bool SavedMessagesTopicId::is_author_hidden() const {
  return dialog_id_ == HIDDEN_AUTHOR_DIALOG_ID;
}

telegram_api::object_ptr<telegram_api::InputPeer> SavedMessagesTopicId::get_input_peer(const Td *td) const {
  return td->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Know);
}

telegram_api::object_ptr<telegram_api::InputDialogPeer> SavedMessagesTopicId::get_input_dialog_peer(
    const Td *td) const {
  return telegram_api::make_object<telegram_api::inputDialogPeer>(get_input_peer(td));
}

void SavedMessagesTopicId::add_dependencies(Dependencies &dependencies) const {
  if (is_author_hidden()) {
    dependencies.add_dialog_dependencies(dialog_id_);
  } else {
    dependencies.add_dialog_and_dependencies(dialog_id_);
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, SavedMessagesTopicId saved_messages_topic_id) {
  if (!saved_messages_topic_id.dialog_id_.is_valid()) {
    return string_builder << "[no Saved Messages topic]";
  }
  if (saved_messages_topic_id.is_author_hidden()) {
    return string_builder << "[Author Hidden topic]";
  }
  return string_builder << "[topic of " << saved_messages_topic_id.dialog_id_ << ']';
}

}  // namespace td
