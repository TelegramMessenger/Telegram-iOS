//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/InputDialogId.h"

#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/UserId.h"

#include "td/utils/algorithm.h"
#include "td/utils/logging.h"

namespace td {

InputDialogId::InputDialogId(const tl_object_ptr<telegram_api::InputPeer> &input_peer) {
  CHECK(input_peer != nullptr);
  switch (input_peer->get_id()) {
    case telegram_api::inputPeerUser::ID: {
      auto input_user = static_cast<const telegram_api::inputPeerUser *>(input_peer.get());
      UserId user_id(input_user->user_id_);
      if (user_id.is_valid()) {
        dialog_id = DialogId(user_id);
        access_hash = input_user->access_hash_;
        return;
      }
      break;
    }
    case telegram_api::inputPeerChat::ID: {
      auto input_chat = static_cast<const telegram_api::inputPeerChat *>(input_peer.get());
      ChatId chat_id(input_chat->chat_id_);
      if (chat_id.is_valid()) {
        dialog_id = DialogId(chat_id);
        return;
      }
      break;
    }
    case telegram_api::inputPeerChannel::ID: {
      auto input_channel = static_cast<const telegram_api::inputPeerChannel *>(input_peer.get());
      ChannelId channel_id(input_channel->channel_id_);
      if (channel_id.is_valid()) {
        dialog_id = DialogId(channel_id);
        access_hash = input_channel->access_hash_;
        return;
      }
      break;
    }
    default:
      break;
  }
  LOG(ERROR) << "Receive " << to_string(input_peer);
}

vector<InputDialogId> InputDialogId::get_input_dialog_ids(
    const vector<tl_object_ptr<telegram_api::InputPeer>> &input_peers,
    FlatHashSet<DialogId, DialogIdHash> *added_dialog_ids) {
  FlatHashSet<DialogId, DialogIdHash> temp_added_dialog_ids;
  if (added_dialog_ids == nullptr) {
    added_dialog_ids = &temp_added_dialog_ids;
  }
  vector<InputDialogId> result;
  result.reserve(input_peers.size());
  for (auto &input_peer : input_peers) {
    InputDialogId input_dialog_id(input_peer);
    if (input_dialog_id.is_valid() && added_dialog_ids->insert(input_dialog_id.get_dialog_id()).second) {
      result.push_back(input_dialog_id);
    }
  }
  return result;
}

vector<DialogId> InputDialogId::get_dialog_ids(const vector<InputDialogId> &input_dialog_ids) {
  return transform(input_dialog_ids, [](InputDialogId input_dialog_id) { return input_dialog_id.get_dialog_id(); });
}

vector<telegram_api::object_ptr<telegram_api::InputDialogPeer>> InputDialogId::get_input_dialog_peers(
    const vector<InputDialogId> &input_dialog_ids) {
  vector<telegram_api::object_ptr<telegram_api::InputDialogPeer>> result;
  result.reserve(input_dialog_ids.size());
  for (const auto &input_dialog_id : input_dialog_ids) {
    auto input_peer = input_dialog_id.get_input_peer();
    if (input_peer != nullptr) {
      result.push_back(telegram_api::make_object<telegram_api::inputDialogPeer>(std::move(input_peer)));
    }
  }
  return result;
}

vector<telegram_api::object_ptr<telegram_api::InputPeer>> InputDialogId::get_input_peers(
    const vector<InputDialogId> &input_dialog_ids) {
  vector<telegram_api::object_ptr<telegram_api::InputPeer>> result;
  result.reserve(input_dialog_ids.size());
  for (const auto &input_dialog_id : input_dialog_ids) {
    auto input_peer = input_dialog_id.get_input_peer();
    CHECK(input_peer != nullptr);
    result.push_back(std::move(input_peer));
  }
  return result;
}

tl_object_ptr<telegram_api::InputPeer> InputDialogId::get_input_peer() const {
  switch (dialog_id.get_type()) {
    case DialogType::User:
      return make_tl_object<telegram_api::inputPeerUser>(dialog_id.get_user_id().get(), access_hash);
    case DialogType::Chat:
      return make_tl_object<telegram_api::inputPeerChat>(dialog_id.get_chat_id().get());
    case DialogType::Channel:
      return make_tl_object<telegram_api::inputPeerChannel>(dialog_id.get_channel_id().get(), access_hash);
    case DialogType::SecretChat:
    case DialogType::None:
      return nullptr;
    default:
      UNREACHABLE();
      return nullptr;
  }
}

bool InputDialogId::are_equivalent(const vector<InputDialogId> &lhs, const vector<InputDialogId> &rhs) {
  auto lhs_it = lhs.begin();
  auto rhs_it = rhs.begin();
  while (lhs_it != lhs.end() || rhs_it != rhs.end()) {
    while (lhs_it != lhs.end() && lhs_it->get_dialog_id().get_type() == DialogType::SecretChat) {
      ++lhs_it;
    }
    while (rhs_it != rhs.end() && rhs_it->get_dialog_id().get_type() == DialogType::SecretChat) {
      ++rhs_it;
    }
    if (lhs_it == lhs.end() || rhs_it == rhs.end()) {
      break;
    }
    if (lhs_it->get_dialog_id() != rhs_it->get_dialog_id()) {
      return false;
    }
    ++lhs_it;
    ++rhs_it;
  }
  return lhs_it == lhs.end() && rhs_it == rhs.end();
}

bool InputDialogId::contains(const vector<InputDialogId> &input_dialog_ids, DialogId dialog_id) {
  for (auto &input_dialog_id : input_dialog_ids) {
    if (input_dialog_id.get_dialog_id() == dialog_id) {
      return true;
    }
  }
  return false;
}

bool InputDialogId::remove(vector<InputDialogId> &input_dialog_ids, DialogId dialog_id) {
  return td::remove_if(input_dialog_ids, [dialog_id](InputDialogId input_dialog_id) {
    return input_dialog_id.get_dialog_id() == dialog_id;
  });
}

}  // namespace td
