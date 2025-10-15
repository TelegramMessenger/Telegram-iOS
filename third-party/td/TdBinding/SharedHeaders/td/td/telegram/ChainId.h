//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/ChatId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/MessageContentType.h"
#include "td/telegram/MessageFullId.h"
#include "td/telegram/PollId.h"
#include "td/telegram/StoryFullId.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"

namespace td {

class ChainId {
  uint64 id = 0;

 public:
  ChainId(ChannelId channel_id) : ChainId(DialogId(channel_id)) {
  }

  ChainId(ChatId chat_id) : ChainId(DialogId(chat_id)) {
  }

  ChainId(DialogId dialog_id, MessageContentType message_content_type)
      : id((static_cast<uint64>(dialog_id.get()) << 10) + get_message_content_chain_id(message_content_type)) {
  }

  ChainId(DialogId dialog_id) : id((static_cast<uint64>(dialog_id.get()) << 10) + 10) {
  }

  ChainId(MessageFullId message_full_id) : ChainId(message_full_id.get_dialog_id()) {
    id += static_cast<uint64>(message_full_id.get_message_id().get()) << 10;
  }

  ChainId(FolderId folder_id) : id((static_cast<uint64>(folder_id.get() + (1 << 30)) << 10)) {
  }

  ChainId(PollId poll_id) : id(static_cast<uint64>(poll_id.get())) {
  }

  ChainId(const string &str) : id(Hash<string>()(str)) {
  }

  ChainId(UserId user_id) : ChainId(DialogId(user_id)) {
  }

  ChainId(StoryFullId story_full_id) : ChainId(story_full_id.get_dialog_id()) {
    id += static_cast<uint64>(story_full_id.get_story_id().get()) << 10;
  }

  uint64 get() const {
    return id;
  }
};

}  // namespace td
