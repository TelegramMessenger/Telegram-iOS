//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/PaidReactionType.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/InputDialogId.h"
#include "td/telegram/Td.h"

#include "td/utils/logging.h"

namespace td {

PaidReactionType::PaidReactionType(Td *td, const telegram_api::object_ptr<telegram_api::PaidReactionPrivacy> &type) {
  CHECK(type != nullptr);
  switch (type->get_id()) {
    case telegram_api::paidReactionPrivacyDefault::ID:
      break;
    case telegram_api::paidReactionPrivacyAnonymous::ID:
      type_ = Type::Anonymous;
      break;
    case telegram_api::paidReactionPrivacyPeer::ID: {
      auto input_dialog_id =
          InputDialogId(static_cast<const telegram_api::paidReactionPrivacyPeer *>(type.get())->peer_);
      auto dialog_id = input_dialog_id.get_dialog_id();
      if (td->dialog_manager_->have_dialog_info(dialog_id)) {
        td->dialog_manager_->force_create_dialog(dialog_id, "PaidReactionType");
        type_ = Type::Dialog;
        dialog_id_ = dialog_id;
      } else {
        LOG(ERROR) << "Receive paid reaction type " << dialog_id;
      }
      break;
    }
    default:
      UNREACHABLE();
      break;
  }
}

PaidReactionType::PaidReactionType(Td *td, const td_api::object_ptr<td_api::PaidReactionType> &type) {
  if (type == nullptr) {
    return;
  }
  switch (type->get_id()) {
    case td_api::paidReactionTypeRegular::ID:
      break;
    case td_api::paidReactionTypeAnonymous::ID:
      type_ = Type::Anonymous;
      break;
    case td_api::paidReactionTypeChat::ID: {
      type_ = Type::Dialog;
      auto dialog_id = DialogId(static_cast<const td_api::paidReactionTypeChat *>(type.get())->chat_id_);
      if (td->dialog_manager_->check_dialog_access(dialog_id, false, AccessRights::Write, "PaidReactionType")
              .is_error() ||
          !td->dialog_manager_->is_broadcast_channel(dialog_id)) {
        break;
      }
      dialog_id_ = dialog_id;
      break;
    }
    default:
      UNREACHABLE();
      break;
  }
}

PaidReactionType PaidReactionType::legacy(bool is_anonymous) {
  PaidReactionType result;
  if (is_anonymous) {
    result.type_ = Type::Anonymous;
  }
  return result;
}

PaidReactionType PaidReactionType::dialog(DialogId dialog_id) {
  PaidReactionType result;
  result.type_ = Type::Dialog;
  result.dialog_id_ = dialog_id;
  return result;
}

telegram_api::object_ptr<telegram_api::PaidReactionPrivacy> PaidReactionType::get_input_paid_reaction_privacy(
    Td *td) const {
  switch (type_) {
    case Type::Regular:
      return telegram_api::make_object<telegram_api::paidReactionPrivacyDefault>();
    case Type::Anonymous:
      return telegram_api::make_object<telegram_api::paidReactionPrivacyAnonymous>();
    case Type::Dialog: {
      auto input_peer = td->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Write);
      if (input_peer == nullptr) {
        return telegram_api::make_object<telegram_api::paidReactionPrivacyAnonymous>();
      }
      return telegram_api::make_object<telegram_api::paidReactionPrivacyPeer>(std::move(input_peer));
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

td_api::object_ptr<td_api::PaidReactionType> PaidReactionType::get_paid_reaction_type_object(Td *td) const {
  switch (type_) {
    case Type::Regular:
      return td_api::make_object<td_api::paidReactionTypeRegular>();
    case Type::Anonymous:
      return td_api::make_object<td_api::paidReactionTypeAnonymous>();
    case Type::Dialog:
      return td_api::make_object<td_api::paidReactionTypeChat>(
          td->dialog_manager_->get_chat_id_object(dialog_id_, "get_paid_reaction_type_object"));
    default:
      UNREACHABLE();
      return nullptr;
  }
}

td_api::object_ptr<td_api::updateDefaultPaidReactionType> PaidReactionType::get_update_default_paid_reaction_type(
    Td *td) const {
  return td_api::make_object<td_api::updateDefaultPaidReactionType>(get_paid_reaction_type_object(td));
}

DialogId PaidReactionType::get_dialog_id(DialogId my_dialog_id) const {
  switch (type_) {
    case Type::Regular:
      return my_dialog_id;
    case Type::Anonymous:
      return DialogId();
    case Type::Dialog:
      return dialog_id_;
    default:
      UNREACHABLE();
      return DialogId();
  }
}

void PaidReactionType::add_dependencies(Dependencies &dependencies) const {
  dependencies.add_dialog_and_dependencies(dialog_id_);
}

bool operator==(const PaidReactionType &lhs, const PaidReactionType &rhs) {
  return lhs.type_ == rhs.type_ && lhs.dialog_id_ == rhs.dialog_id_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const PaidReactionType &paid_reaction_type) {
  switch (paid_reaction_type.type_) {
    case PaidReactionType::Type::Regular:
      return string_builder << "non-anonymous paid reaction";
    case PaidReactionType::Type::Anonymous:
      return string_builder << "anonymous paid reaction";
    case PaidReactionType::Type::Dialog:
      return string_builder << "paid reaction via " << paid_reaction_type.dialog_id_;
    default:
      UNREACHABLE();
      return string_builder;
  }
}

}  // namespace td
