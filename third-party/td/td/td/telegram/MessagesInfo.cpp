//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessagesInfo.h"

#include "td/telegram/ChatManager.h"
#include "td/telegram/ForumTopicManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserManager.h"

#include "td/utils/logging.h"
#include "td/utils/misc.h"

namespace td {

MessagesInfo get_messages_info(Td *td, DialogId dialog_id,
                               telegram_api::object_ptr<telegram_api::messages_Messages> &&messages_ptr,
                               const char *source) {
  CHECK(messages_ptr != nullptr);
  LOG(DEBUG) << "Receive result for " << source << ": " << to_string(messages_ptr);

  vector<tl_object_ptr<telegram_api::User>> users;
  vector<tl_object_ptr<telegram_api::Chat>> chats;
  vector<tl_object_ptr<telegram_api::ForumTopic>> topics;
  MessagesInfo result;
  switch (messages_ptr->get_id()) {
    case telegram_api::messages_messages::ID: {
      auto messages = move_tl_object_as<telegram_api::messages_messages>(messages_ptr);

      users = std::move(messages->users_);
      chats = std::move(messages->chats_);
      result.total_count = narrow_cast<int32>(messages->messages_.size());
      result.messages = std::move(messages->messages_);
      break;
    }
    case telegram_api::messages_messagesSlice::ID: {
      auto messages = move_tl_object_as<telegram_api::messages_messagesSlice>(messages_ptr);

      users = std::move(messages->users_);
      chats = std::move(messages->chats_);
      result.total_count = messages->count_;
      result.messages = std::move(messages->messages_);
      result.next_rate = messages->next_rate_;
      // inexact:flags.1?true offset_id_offset:flags.2?int
      break;
    }
    case telegram_api::messages_channelMessages::ID: {
      auto messages = move_tl_object_as<telegram_api::messages_channelMessages>(messages_ptr);

      users = std::move(messages->users_);
      chats = std::move(messages->chats_);
      topics = std::move(messages->topics_);
      result.total_count = messages->count_;
      result.messages = std::move(messages->messages_);
      result.is_channel_messages = true;
      // inexact:flags.1?true pts:int offset_id_offset:flags.2?int
      break;
    }
    case telegram_api::messages_messagesNotModified::ID:
      LOG(ERROR) << "Server returned messagesNotModified in response to " << source;
      break;
    default:
      UNREACHABLE();
      break;
  }

  td->user_manager_->on_get_users(std::move(users), source);
  td->chat_manager_->on_get_chats(std::move(chats), source);
  td->forum_topic_manager_->on_get_forum_topic_infos(dialog_id, std::move(topics), source);

  return result;
}

}  // namespace td
