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
#include "td/telegram/SecretChatId.h"
#include "td/telegram/StoryFullId.h"
#include "td/telegram/UserId.h"
#include "td/telegram/WebPageId.h"

#include "td/utils/FlatHashSet.h"

namespace td {

class Td;

class Dependencies {
  FlatHashSet<UserId, UserIdHash> user_ids;
  FlatHashSet<ChatId, ChatIdHash> chat_ids;
  FlatHashSet<ChannelId, ChannelIdHash> channel_ids;
  FlatHashSet<SecretChatId, SecretChatIdHash> secret_chat_ids;
  FlatHashSet<DialogId, DialogIdHash> dialog_ids;
  FlatHashSet<WebPageId, WebPageIdHash> web_page_ids;
  FlatHashSet<StoryFullId, StoryFullIdHash> story_full_ids;

 public:
  void add(UserId user_id);

  void add(ChatId chat_id);

  void add(ChannelId channel_id);

  void add(SecretChatId secret_chat_id);

  void add(WebPageId web_page_id);

  void add(StoryFullId story_full_id);

  void add_dialog_and_dependencies(DialogId dialog_id);

  void add_dialog_dependencies(DialogId dialog_id);

  void add_message_sender_dependencies(DialogId dialog_id);

  bool resolve_force(Td *td, const char *source, bool ignore_errors = false) const;

  const FlatHashSet<DialogId, DialogIdHash> &get_dialog_ids() const {
    return dialog_ids;
  }
};

}  // namespace td
