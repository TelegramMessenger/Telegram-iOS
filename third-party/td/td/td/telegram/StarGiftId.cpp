//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StarGiftId.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/Td.h"

#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"

namespace td {

StarGiftId::StarGiftId(ServerMessageId server_message_id) {
  if (server_message_id.is_valid()) {
    type_ = Type::ForUser;
    server_message_id_ = server_message_id;
  } else if (server_message_id != ServerMessageId()) {
    LOG(ERROR) << "Receive server message " << server_message_id.get();
  }
}

StarGiftId::StarGiftId(DialogId dialog_id, int64 saved_id) {
  if (dialog_id == DialogId()) {
    return;
  }
  if (dialog_id.get_type() != DialogType::Channel || saved_id == 0) {
    LOG(ERROR) << "Receive gift " << saved_id << " in " << dialog_id;
    return;
  }
  type_ = Type::ForDialog;
  dialog_id_ = dialog_id;
  saved_id_ = saved_id;
}

StarGiftId::StarGiftId(const string &star_gift_id) {
  if (star_gift_id.empty()) {
    return;
  }
  auto underscore_pos = star_gift_id.find('_');
  if (underscore_pos == string::npos) {
    type_ = Type::ForUser;
    server_message_id_ = ServerMessageId(to_integer<int32>(star_gift_id));
  } else {
    type_ = Type::ForDialog;
    dialog_id_ = DialogId(to_integer<int64>(star_gift_id));
    saved_id_ = to_integer<int64>(Slice(star_gift_id).substr(underscore_pos + 1));
  }
  if (get_star_gift_id() != star_gift_id) {
    *this = {};
  }
}

telegram_api::object_ptr<telegram_api::InputSavedStarGift> StarGiftId::get_input_saved_star_gift(Td *td) const {
  switch (type_) {
    case Type::Empty:
      return nullptr;
    case Type::ForUser:
      return telegram_api::make_object<telegram_api::inputSavedStarGiftUser>(server_message_id_.get());
    case Type::ForDialog: {
      auto input_peer = td->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
      if (input_peer == nullptr) {
        return nullptr;
      }
      return telegram_api::make_object<telegram_api::inputSavedStarGiftChat>(std::move(input_peer), saved_id_);
    }
    default:
      UNREACHABLE();
      return nullptr;
  }
}

string StarGiftId::get_star_gift_id() const {
  switch (type_) {
    case Type::Empty:
      return string();
    case Type::ForUser:
      return PSTRING() << server_message_id_.get();
    case Type::ForDialog:
      return PSTRING() << dialog_id_.get() << '_' << saved_id_;
    default:
      UNREACHABLE();
      return string();
  }
}

DialogId StarGiftId::get_dialog_id(const Td *td) const {
  switch (type_) {
    case Type::Empty:
      return DialogId();
    case Type::ForUser:
      return td->dialog_manager_->get_my_dialog_id();
    case Type::ForDialog:
      return dialog_id_;
    default:
      UNREACHABLE();
      return DialogId();
  }
}

bool operator==(const StarGiftId &lhs, const StarGiftId &rhs) {
  return lhs.type_ == rhs.type_ && lhs.server_message_id_ == rhs.server_message_id_ &&
         lhs.dialog_id_ == rhs.dialog_id_ && lhs.saved_id_ == rhs.saved_id_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const StarGiftId &star_gift_id) {
  switch (star_gift_id.type_) {
    case StarGiftId::Type::Empty:
      return string_builder << "unknown gift";
    case StarGiftId::Type::ForUser:
      return string_builder << "user gift from " << MessageId(star_gift_id.server_message_id_);
    case StarGiftId::Type::ForDialog:
      return string_builder << star_gift_id.dialog_id_ << " gift " << star_gift_id.saved_id_;
    default:
      UNREACHABLE();
      return string_builder;
  }
}

}  // namespace td
