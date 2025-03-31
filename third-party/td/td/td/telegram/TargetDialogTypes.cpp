//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/TargetDialogTypes.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"

namespace td {

TargetDialogTypes::TargetDialogTypes(const vector<telegram_api::object_ptr<telegram_api::InlineQueryPeerType>> &types) {
  for (const auto &peer_type : types) {
    CHECK(peer_type != nullptr);
    switch (peer_type->get_id()) {
      case telegram_api::inlineQueryPeerTypePM::ID:
        mask_ |= USERS_MASK;
        break;
      case telegram_api::inlineQueryPeerTypeBotPM::ID:
        mask_ |= BOTS_MASK;
        break;
      case telegram_api::inlineQueryPeerTypeChat::ID:
      case telegram_api::inlineQueryPeerTypeMegagroup::ID:
        mask_ |= CHATS_MASK;
        break;
      case telegram_api::inlineQueryPeerTypeBroadcast::ID:
        mask_ |= BROADCASTS_MASK;
        break;
      default:
        LOG(ERROR) << "Receive " << to_string(peer_type);
    }
  }
}

Result<TargetDialogTypes> TargetDialogTypes::get_target_dialog_types(
    const td_api::object_ptr<td_api::targetChatTypes> &types) {
  int64 mask = 0;
  if (types != nullptr) {
    if (types->allow_user_chats_) {
      mask |= USERS_MASK;
    }
    if (types->allow_bot_chats_) {
      mask |= BOTS_MASK;
    }
    if (types->allow_group_chats_) {
      mask |= CHATS_MASK;
    }
    if (types->allow_channel_chats_) {
      mask |= BROADCASTS_MASK;
    }
  }
  if (mask == 0) {
    return Status::Error(400, "At least one chat type must be allowed");
  }
  return TargetDialogTypes(mask);
}

vector<telegram_api::object_ptr<telegram_api::InlineQueryPeerType>> TargetDialogTypes::get_input_peer_types() const {
  vector<telegram_api::object_ptr<telegram_api::InlineQueryPeerType>> peer_types;
  if (mask_ == FULL_MASK) {
    return peer_types;
  }
  if ((mask_ & USERS_MASK) != 0) {
    peer_types.push_back(telegram_api::make_object<telegram_api::inlineQueryPeerTypePM>());
  }
  if ((mask_ & BOTS_MASK) != 0) {
    peer_types.push_back(telegram_api::make_object<telegram_api::inlineQueryPeerTypeBotPM>());
  }
  if ((mask_ & CHATS_MASK) != 0) {
    peer_types.push_back(telegram_api::make_object<telegram_api::inlineQueryPeerTypeChat>());
    peer_types.push_back(telegram_api::make_object<telegram_api::inlineQueryPeerTypeMegagroup>());
  }
  if ((mask_ & BROADCASTS_MASK) != 0) {
    peer_types.push_back(telegram_api::make_object<telegram_api::inlineQueryPeerTypeBroadcast>());
  }
  return peer_types;
}

td_api::object_ptr<td_api::targetChatTypes> TargetDialogTypes::get_target_chat_types_object() const {
  auto mask = get_full_mask();
  return td_api::make_object<td_api::targetChatTypes>((mask & USERS_MASK) != 0, (mask & BOTS_MASK) != 0,
                                                      (mask & CHATS_MASK) != 0, (mask & BROADCASTS_MASK) != 0);
}

StringBuilder &operator<<(StringBuilder &string_builder, const TargetDialogTypes &types) {
  auto mask = types.get_full_mask();
  if ((mask & TargetDialogTypes::USERS_MASK) != 0) {
    string_builder << "(users)";
  }
  if ((mask & TargetDialogTypes::BOTS_MASK) != 0) {
    string_builder << "(bots)";
  }
  if ((mask & TargetDialogTypes::CHATS_MASK) != 0) {
    string_builder << "(groups)";
  }
  if ((mask & TargetDialogTypes::BROADCASTS_MASK) != 0) {
    string_builder << "(channels)";
  }
  return string_builder;
}

}  // namespace td
