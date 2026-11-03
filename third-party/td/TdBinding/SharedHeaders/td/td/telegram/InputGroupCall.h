//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ServerMessageId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

class InputGroupCall {
  string slug_;

  ServerMessageId server_message_id_;

 public:
  static Result<InputGroupCall> get_input_group_call(Td *td,
                                                     td_api::object_ptr<td_api::InputGroupCall> &&input_group_call);

  bool operator==(const InputGroupCall &other) const {
    return slug_ == other.slug_ && server_message_id_ == other.server_message_id_;
  }

  bool operator!=(const InputGroupCall &other) const {
    return !(*this == other);
  }

  uint32 get_hash() const {
    return slug_.empty() ? server_message_id_.get() : Hash<string>()(slug_);
  }

  telegram_api::object_ptr<telegram_api::InputGroupCall> get_input_group_call() const;

  friend StringBuilder &operator<<(StringBuilder &string_builder, InputGroupCall input_group_call);
};

struct InputGroupCallHash {
  uint32 operator()(InputGroupCall input_group_call) const {
    return input_group_call.get_hash();
  }
};

}  // namespace td
