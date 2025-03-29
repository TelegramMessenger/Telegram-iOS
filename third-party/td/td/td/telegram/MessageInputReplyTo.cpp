//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageInputReplyTo.h"

#include "td/telegram/AccessRights.h"
#include "td/telegram/Dependencies.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/DialogManager.h"
#include "td/telegram/InputDialogId.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/StoryId.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/logging.h"

namespace td {

MessageInputReplyTo::~MessageInputReplyTo() = default;

MessageInputReplyTo::MessageInputReplyTo(Td *td,
                                         telegram_api::object_ptr<telegram_api::InputReplyTo> &&input_reply_to) {
  if (input_reply_to == nullptr) {
    return;
  }
  switch (input_reply_to->get_id()) {
    case telegram_api::inputReplyToStory::ID: {
      auto reply_to = telegram_api::move_object_as<telegram_api::inputReplyToStory>(input_reply_to);
      auto dialog_id = InputDialogId(reply_to->peer_).get_dialog_id();
      auto story_id = StoryId(reply_to->story_id_);
      if (dialog_id.is_valid() && story_id.is_valid()) {
        td->dialog_manager_->force_create_dialog(dialog_id, "MessageInputReplyTo", true);
        story_full_id_ = {dialog_id, story_id};
      }
      break;
    }
    case telegram_api::inputReplyToMessage::ID: {
      auto reply_to = telegram_api::move_object_as<telegram_api::inputReplyToMessage>(input_reply_to);
      MessageId message_id(ServerMessageId(reply_to->reply_to_msg_id_));
      if (!message_id.is_valid() && !message_id_.is_valid_scheduled()) {
        return;
      }
      DialogId dialog_id;
      if (reply_to->reply_to_peer_id_ != nullptr) {
        dialog_id = InputDialogId(reply_to->reply_to_peer_id_).get_dialog_id();
        if (!dialog_id.is_valid() || !td->dialog_manager_->have_input_peer(dialog_id, false, AccessRights::Read)) {
          return;
        }
        td->dialog_manager_->force_create_dialog(dialog_id, "inputReplyToMessage");
      }
      message_id_ = message_id;
      dialog_id_ = dialog_id;

      quote_ = MessageQuote(td, reply_to);
      break;
    }
    default:
      UNREACHABLE();
  }
}

void MessageInputReplyTo::add_dependencies(Dependencies &dependencies) const {
  dependencies.add_dialog_and_dependencies(dialog_id_);
  quote_.add_dependencies(dependencies);
  dependencies.add_dialog_and_dependencies(story_full_id_.get_dialog_id());  // just in case
}

telegram_api::object_ptr<telegram_api::InputReplyTo> MessageInputReplyTo::get_input_reply_to(
    Td *td, MessageId top_thread_message_id) const {
  if (story_full_id_.is_valid()) {
    auto dialog_id = story_full_id_.get_dialog_id();
    auto input_peer = td->dialog_manager_->get_input_peer(dialog_id, AccessRights::Read);
    if (input_peer == nullptr) {
      LOG(INFO) << "Failed to get input peer for " << story_full_id_;
      return nullptr;
    }
    return telegram_api::make_object<telegram_api::inputReplyToStory>(std::move(input_peer),
                                                                      story_full_id_.get_story_id().get());
  }
  auto reply_to_message_id = message_id_;
  if (reply_to_message_id == MessageId()) {
    if (top_thread_message_id == MessageId()) {
      return nullptr;
    }
    reply_to_message_id = top_thread_message_id;
  }
  CHECK(reply_to_message_id.is_server());
  int32 flags = 0;
  if (top_thread_message_id != MessageId()) {
    CHECK(top_thread_message_id.is_server());
    flags |= telegram_api::inputReplyToMessage::TOP_MSG_ID_MASK;
  }
  telegram_api::object_ptr<telegram_api::InputPeer> input_peer;
  if (dialog_id_ != DialogId()) {
    input_peer = td->dialog_manager_->get_input_peer(dialog_id_, AccessRights::Read);
    if (input_peer == nullptr) {
      LOG(INFO) << "Failed to get input peer for " << dialog_id_;
      return nullptr;
    }
    flags |= telegram_api::inputReplyToMessage::REPLY_TO_PEER_ID_MASK;
  }
  auto result = telegram_api::make_object<telegram_api::inputReplyToMessage>(
      flags, reply_to_message_id.get_server_message_id().get(), top_thread_message_id.get_server_message_id().get(),
      std::move(input_peer), string(), Auto(), 0);
  quote_.update_input_reply_to_message(td, result.get());
  return std::move(result);
}

// only for draft messages
td_api::object_ptr<td_api::InputMessageReplyTo> MessageInputReplyTo::get_input_message_reply_to_object(Td *td) const {
  if (story_full_id_.is_valid()) {
    return td_api::make_object<td_api::inputMessageReplyToStory>(
        td->dialog_manager_->get_chat_id_object(story_full_id_.get_dialog_id(), "inputMessageReplyToStory"),
        story_full_id_.get_story_id().get());
  }
  if (!message_id_.is_valid() && !message_id_.is_valid_scheduled()) {
    return nullptr;
  }
  if (dialog_id_ != DialogId()) {
    return td_api::make_object<td_api::inputMessageReplyToExternalMessage>(
        td->dialog_manager_->get_chat_id_object(dialog_id_, "inputMessageReplyToExternalMessage"), message_id_.get(),
        quote_.get_input_text_quote_object(td->user_manager_.get()));
  }
  return td_api::make_object<td_api::inputMessageReplyToMessage>(
      message_id_.get(), quote_.get_input_text_quote_object(td->user_manager_.get()));
}

MessageId MessageInputReplyTo::get_same_chat_reply_to_message_id() const {
  return dialog_id_ == DialogId() && (message_id_.is_valid() || message_id_.is_valid_scheduled()) ? message_id_
                                                                                                  : MessageId();
}

MessageFullId MessageInputReplyTo::get_reply_message_full_id(DialogId owner_dialog_id) const {
  if (!message_id_.is_valid() && !message_id_.is_valid_scheduled()) {
    return {};
  }
  return {dialog_id_ != DialogId() ? dialog_id_ : owner_dialog_id, message_id_};
}

bool operator==(const MessageInputReplyTo &lhs, const MessageInputReplyTo &rhs) {
  return lhs.message_id_ == rhs.message_id_ && lhs.dialog_id_ == rhs.dialog_id_ &&
         lhs.story_full_id_ == rhs.story_full_id_ && lhs.quote_ == rhs.quote_;
}

bool operator!=(const MessageInputReplyTo &lhs, const MessageInputReplyTo &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageInputReplyTo &input_reply_to) {
  if (input_reply_to.message_id_.is_valid() || input_reply_to.message_id_.is_valid_scheduled()) {
    string_builder << input_reply_to.message_id_;
    if (input_reply_to.dialog_id_ != DialogId()) {
      string_builder << " in " << input_reply_to.dialog_id_;
    }
    return string_builder << input_reply_to.quote_;
  }
  if (input_reply_to.story_full_id_.is_valid()) {
    return string_builder << input_reply_to.story_full_id_;
  }
  return string_builder << "nothing";
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageInputReplyTo *input_reply_to_ptr) {
  if (input_reply_to_ptr == nullptr) {
    return string_builder << "nothing";
  }
  return string_builder << *input_reply_to_ptr;
}

}  // namespace td
