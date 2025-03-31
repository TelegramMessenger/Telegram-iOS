//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogId.h"

#include "td/utils/algorithm.h"
#include "td/utils/logging.h"

#include <limits>

namespace td {

bool DialogId::is_valid() const {
  return get_type() != DialogType::None;
}

DialogType DialogId::get_type() const {
  // check that valid ranges are continuous
  static_assert(ZERO_CHANNEL_ID + 1 == -ChatId::MAX_CHAT_ID, "");
  static_assert(
      ZERO_SECRET_CHAT_ID + std::numeric_limits<int32>::max() + 1 == ZERO_CHANNEL_ID - ChannelId::MAX_CHANNEL_ID, "");

  if (id < 0) {
    if (-ChatId::MAX_CHAT_ID <= id) {
      return DialogType::Chat;
    }
    if (ZERO_CHANNEL_ID - ChannelId::MAX_CHANNEL_ID <= id && id != ZERO_CHANNEL_ID) {
      return DialogType::Channel;
    }
    if (ZERO_SECRET_CHAT_ID + std::numeric_limits<int32>::min() <= id && id != ZERO_SECRET_CHAT_ID) {
      return DialogType::SecretChat;
    }
  } else if (0 < id && id <= UserId::MAX_USER_ID) {
    return DialogType::User;
  }
  return DialogType::None;
}

UserId DialogId::get_user_id() const {
  CHECK(get_type() == DialogType::User);
  return UserId(id);
}

ChatId DialogId::get_chat_id() const {
  CHECK(get_type() == DialogType::Chat);
  return ChatId(-id);
}

ChannelId DialogId::get_channel_id() const {
  CHECK(get_type() == DialogType::Channel);
  return ChannelId(ZERO_CHANNEL_ID - id);
}

SecretChatId DialogId::get_secret_chat_id() const {
  CHECK(get_type() == DialogType::SecretChat);
  return SecretChatId(static_cast<int32>(id - ZERO_SECRET_CHAT_ID));
}

DialogId::DialogId(UserId user_id) {
  if (user_id.is_valid()) {
    id = user_id.get();
  } else {
    id = 0;
  }
}

DialogId::DialogId(ChatId chat_id) {
  if (chat_id.is_valid()) {
    id = -chat_id.get();
  } else {
    id = 0;
  }
}

DialogId::DialogId(ChannelId channel_id) {
  if (channel_id.is_valid()) {
    id = ZERO_CHANNEL_ID - channel_id.get();
  } else {
    id = 0;
  }
}

DialogId::DialogId(SecretChatId secret_chat_id) {
  if (secret_chat_id.is_valid()) {
    id = ZERO_SECRET_CHAT_ID + static_cast<int64>(secret_chat_id.get());
  } else {
    id = 0;
  }
}

DialogId::DialogId(const tl_object_ptr<telegram_api::DialogPeer> &dialog_peer) {
  CHECK(dialog_peer != nullptr);
  switch (dialog_peer->get_id()) {
    case telegram_api::dialogPeer::ID:
      id = get_peer_id(static_cast<const telegram_api::dialogPeer *>(dialog_peer.get())->peer_);
      break;
    case telegram_api::dialogPeerFolder::ID:
      LOG(ERROR) << "Receive unsupported " << to_string(dialog_peer);
      id = 0;
      break;
    default:
      id = 0;
      UNREACHABLE();
  }
}

DialogId::DialogId(const tl_object_ptr<telegram_api::Peer> &peer) : id(get_peer_id(peer)) {
}

int64 DialogId::get_peer_id(const tl_object_ptr<telegram_api::Peer> &peer) {
  CHECK(peer != nullptr);

  switch (peer->get_id()) {
    case telegram_api::peerUser::ID: {
      auto peer_user = static_cast<const telegram_api::peerUser *>(peer.get());
      UserId user_id(peer_user->user_id_);
      if (!user_id.is_valid()) {
        LOG(ERROR) << "Receive invalid " << user_id;
        return 0;
      }

      return user_id.get();
    }
    case telegram_api::peerChat::ID: {
      auto peer_chat = static_cast<const telegram_api::peerChat *>(peer.get());
      ChatId chat_id(peer_chat->chat_id_);
      if (!chat_id.is_valid()) {
        LOG(ERROR) << "Receive invalid " << chat_id;
        return 0;
      }

      return -chat_id.get();
    }
    case telegram_api::peerChannel::ID: {
      auto peer_channel = static_cast<const telegram_api::peerChannel *>(peer.get());
      ChannelId channel_id(peer_channel->channel_id_);
      if (!channel_id.is_valid()) {
        LOG(ERROR) << "Receive invalid " << channel_id;
        return 0;
      }

      return ZERO_CHANNEL_ID - channel_id.get();
    }
    default:
      UNREACHABLE();
      return 0;
  }
}

DialogId DialogId::get_message_dialog_id(const telegram_api::Message *message_ptr) {
  CHECK(message_ptr != nullptr);
  switch (message_ptr->get_id()) {
    case telegram_api::messageEmpty::ID: {
      auto message = static_cast<const telegram_api::messageEmpty *>(message_ptr);
      return message->peer_id_ == nullptr ? DialogId() : DialogId(message->peer_id_);
    }
    case telegram_api::message::ID: {
      auto message = static_cast<const telegram_api::message *>(message_ptr);
      return DialogId(message->peer_id_);
    }
    case telegram_api::messageService::ID: {
      auto message = static_cast<const telegram_api::messageService *>(message_ptr);
      return DialogId(message->peer_id_);
    }
    default:
      UNREACHABLE();
      return DialogId();
  }
}

DialogId DialogId::get_message_dialog_id(const tl_object_ptr<telegram_api::Message> &message_ptr) {
  return get_message_dialog_id(message_ptr.get());
}

vector<DialogId> DialogId::get_dialog_ids(const vector<int64> &chat_ids) {
  return transform(chat_ids, [](int64 chat_id) { return DialogId(chat_id); });
}

vector<DialogId> DialogId::remove_secret_chat_dialog_ids(vector<DialogId> dialog_ids) {
  td::remove_if(dialog_ids, [](DialogId dialog_id) { return dialog_id.get_type() == DialogType::SecretChat; });
  return dialog_ids;
}

}  // namespace td
