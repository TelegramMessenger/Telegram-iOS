//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/MessageId.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

struct MessageSearchOffset {
  int32 date_ = 0;
  MessageId message_id_;
  DialogId dialog_id_;

  void update_from_message(const telegram_api::object_ptr<telegram_api::Message> &message);

  string to_string() const;

  static Result<MessageSearchOffset> from_string(const string &offset);
};

}  // namespace td
