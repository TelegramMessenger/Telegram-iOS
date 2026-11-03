//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/mtproto/MessageId.h"

#include "td/utils/common.h"

namespace td {
namespace mtproto {

struct PacketInfo {
  enum { Common, EndToEnd } type = Common;
  uint32 message_ack{0};

  uint64 salt{0};
  uint64 session_id{0};

  MessageId message_id;
  int32 seq_no{0};
  int32 version{1};
  bool no_crypto_flag{false};
  bool is_creator{false};
  bool check_mod4{true};
  bool use_random_padding{false};
};

}  // namespace mtproto
}  // namespace td
