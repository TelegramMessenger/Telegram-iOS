//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/MessageId.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"

namespace td {
namespace mtproto {

struct MtprotoQuery {
  MessageId message_id;
  int32 seq_no;
  BufferSlice packet;
  bool gzip_flag;
  vector<MessageId> invoke_after_message_ids;
  bool use_quick_ack;
};

}  // namespace mtproto
}  // namespace td
