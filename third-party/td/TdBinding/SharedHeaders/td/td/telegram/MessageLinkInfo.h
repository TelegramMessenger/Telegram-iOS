//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ChannelId.h"
#include "td/telegram/DialogId.h"
#include "td/telegram/MessageId.h"

#include "td/utils/common.h"

namespace td {

struct MessageLinkInfo {
  string username;
  // or
  ChannelId channel_id;

  MessageId message_id;
  bool is_single = false;
  int32 media_timestamp = 0;

  MessageId top_thread_message_id;

  DialogId comment_dialog_id;
  MessageId comment_message_id;
  bool for_comment = false;
};

}  // namespace td
