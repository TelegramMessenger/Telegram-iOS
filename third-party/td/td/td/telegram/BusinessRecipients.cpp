//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BusinessRecipients.h"

#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserManager.h"

#include "td/utils/algorithm.h"

namespace td {

BusinessRecipients::BusinessRecipients(telegram_api::object_ptr<telegram_api::businessRecipients> recipients)
    : user_ids_(UserId::get_user_ids(recipients->users_, true))
    , existing_chats_(recipients->existing_chats_)
    , new_chats_(recipients->new_chats_)
    , contacts_(recipients->contacts_)
    , non_contacts_(recipients->non_contacts_)
    , exclude_selected_(recipients->exclude_selected_) {
}

BusinessRecipients::BusinessRecipients(telegram_api::object_ptr<telegram_api::businessBotRecipients> recipients)
    : user_ids_(UserId::get_user_ids(recipients->users_, true))
    , excluded_user_ids_(UserId::get_user_ids(recipients->exclude_users_, true))
    , existing_chats_(recipients->existing_chats_)
    , new_chats_(recipients->new_chats_)
    , contacts_(recipients->contacts_)
    , non_contacts_(recipients->non_contacts_)
    , exclude_selected_(recipients->exclude_selected_) {
}

BusinessRecipients::BusinessRecipients(td_api::object_ptr<td_api::businessRecipients> recipients, bool allow_excluded) {
  if (recipients == nullptr) {
    return;
  }
  for (auto chat_id : recipients->chat_ids_) {
    DialogId dialog_id(chat_id);
    if (dialog_id.get_type() == DialogType::User) {
      user_ids_.push_back(dialog_id.get_user_id());
    }
  }
  if (allow_excluded) {
    for (auto chat_id : recipients->excluded_chat_ids_) {
      DialogId dialog_id(chat_id);
      if (dialog_id.get_type() == DialogType::User) {
        excluded_user_ids_.push_back(dialog_id.get_user_id());
      }
    }
    if (recipients->exclude_selected_) {
      append(user_ids_, std::move(excluded_user_ids_));
      reset_to_empty(excluded_user_ids_);
    }
  }
  existing_chats_ = recipients->select_existing_chats_;
  new_chats_ = recipients->select_new_chats_;
  contacts_ = recipients->select_contacts_;
  non_contacts_ = recipients->select_non_contacts_;
  exclude_selected_ = recipients->exclude_selected_;
}

td_api::object_ptr<td_api::businessRecipients> BusinessRecipients::get_business_recipients_object(Td *td) const {
  vector<int64> chat_ids;
  for (auto user_id : user_ids_) {
    DialogId dialog_id(user_id);
    td->dialog_manager_->force_create_dialog(dialog_id, "get_business_recipients_object", true);
    CHECK(td->dialog_manager_->have_dialog_force(dialog_id, "get_business_recipients_object"));
    chat_ids.push_back(td->dialog_manager_->get_chat_id_object(dialog_id, "businessRecipients"));
  }
  vector<int64> excluded_chat_ids;
  for (auto user_id : excluded_user_ids_) {
    DialogId dialog_id(user_id);
    td->dialog_manager_->force_create_dialog(dialog_id, "get_business_recipients_object", true);
    CHECK(td->dialog_manager_->have_dialog_force(dialog_id, "get_business_recipients_object"));
    excluded_chat_ids.push_back(td->dialog_manager_->get_chat_id_object(dialog_id, "businessRecipients"));
  }
  return td_api::make_object<td_api::businessRecipients>(std::move(chat_ids), std::move(excluded_chat_ids),
                                                         existing_chats_, new_chats_, contacts_, non_contacts_,
                                                         exclude_selected_);
}

telegram_api::object_ptr<telegram_api::inputBusinessRecipients> BusinessRecipients::get_input_business_recipients(
    Td *td) const {
  int32 flags = 0;
  if (existing_chats_) {
    flags |= telegram_api::inputBusinessRecipients::EXISTING_CHATS_MASK;
  }
  if (new_chats_) {
    flags |= telegram_api::inputBusinessRecipients::NEW_CHATS_MASK;
  }
  if (contacts_) {
    flags |= telegram_api::inputBusinessRecipients::CONTACTS_MASK;
  }
  if (non_contacts_) {
    flags |= telegram_api::inputBusinessRecipients::NON_CONTACTS_MASK;
  }
  if (exclude_selected_) {
    flags |= telegram_api::inputBusinessRecipients::EXCLUDE_SELECTED_MASK;
  }
  vector<telegram_api::object_ptr<telegram_api::InputUser>> input_users;
  for (auto user_id : user_ids_) {
    auto r_input_user = td->user_manager_->get_input_user(user_id);
    if (r_input_user.is_ok()) {
      input_users.push_back(r_input_user.move_as_ok());
    }
  }
  if (!input_users.empty()) {
    flags |= telegram_api::inputBusinessRecipients::USERS_MASK;
  }
  return telegram_api::make_object<telegram_api::inputBusinessRecipients>(flags, false /*ignored*/, false /*ignored*/,
                                                                          false /*ignored*/, false /*ignored*/,
                                                                          false /*ignored*/, std::move(input_users));
}

telegram_api::object_ptr<telegram_api::inputBusinessBotRecipients>
BusinessRecipients::get_input_business_bot_recipients(Td *td) const {
  int32 flags = 0;
  if (existing_chats_) {
    flags |= telegram_api::inputBusinessBotRecipients::EXISTING_CHATS_MASK;
  }
  if (new_chats_) {
    flags |= telegram_api::inputBusinessBotRecipients::NEW_CHATS_MASK;
  }
  if (contacts_) {
    flags |= telegram_api::inputBusinessBotRecipients::CONTACTS_MASK;
  }
  if (non_contacts_) {
    flags |= telegram_api::inputBusinessBotRecipients::NON_CONTACTS_MASK;
  }
  if (exclude_selected_) {
    flags |= telegram_api::inputBusinessBotRecipients::EXCLUDE_SELECTED_MASK;
  }
  vector<telegram_api::object_ptr<telegram_api::InputUser>> input_users;
  for (auto user_id : user_ids_) {
    auto r_input_user = td->user_manager_->get_input_user(user_id);
    if (r_input_user.is_ok()) {
      input_users.push_back(r_input_user.move_as_ok());
    }
  }
  if (!input_users.empty()) {
    flags |= telegram_api::inputBusinessBotRecipients::USERS_MASK;
  }
  vector<telegram_api::object_ptr<telegram_api::InputUser>> excluded_input_users;
  for (auto user_id : excluded_user_ids_) {
    auto r_input_user = td->user_manager_->get_input_user(user_id);
    if (r_input_user.is_ok()) {
      excluded_input_users.push_back(r_input_user.move_as_ok());
    }
  }
  if (!excluded_input_users.empty()) {
    flags |= telegram_api::inputBusinessBotRecipients::EXCLUDE_USERS_MASK;
  }
  return telegram_api::make_object<telegram_api::inputBusinessBotRecipients>(
      flags, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/, false /*ignored*/,
      std::move(input_users), std::move(excluded_input_users));
}

void BusinessRecipients::add_dependencies(Dependencies &dependencies) const {
  for (auto user_id : user_ids_) {
    dependencies.add(user_id);
  }
  for (auto user_id : excluded_user_ids_) {
    dependencies.add(user_id);
  }
}

bool operator==(const BusinessRecipients &lhs, const BusinessRecipients &rhs) {
  return lhs.user_ids_ == rhs.user_ids_ && lhs.excluded_user_ids_ == rhs.excluded_user_ids_ &&
         lhs.existing_chats_ == rhs.existing_chats_ && lhs.new_chats_ == rhs.new_chats_ &&
         lhs.contacts_ == rhs.contacts_ && lhs.non_contacts_ == rhs.non_contacts_ &&
         lhs.exclude_selected_ == rhs.exclude_selected_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessRecipients &recipients) {
  return string_builder << "received by " << (recipients.exclude_selected_ ? "all private chats except " : "")
                        << recipients.user_ids_ << (recipients.contacts_ ? ", contacts " : "")
                        << (recipients.non_contacts_ ? ", non-contacts " : "")
                        << (recipients.existing_chats_ ? ", existing chats " : "")
                        << (recipients.new_chats_ ? ", new chats " : "");
}

}  // namespace td
