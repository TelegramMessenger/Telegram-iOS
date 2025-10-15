//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"

namespace td {

class Td;

struct MessagesInfo {
  vector<telegram_api::object_ptr<telegram_api::Message>> messages;
  int32 total_count = 0;
  int32 next_rate = -1;
  bool is_channel_messages = false;
};

MessagesInfo get_messages_info(Td *td, DialogId dialog_id,
                               telegram_api::object_ptr<telegram_api::messages_Messages> &&messages_ptr,
                               const char *source);

}  // namespace td
