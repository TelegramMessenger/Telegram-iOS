//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"

namespace td {

struct CallDiscardReason {
  enum class Type : int32 { Empty, Missed, Disconnected, HungUp, Declined, AllowGroupCall };
  Type type_ = Type::Empty;
  string encrypted_key_;
};

CallDiscardReason get_call_discard_reason(const telegram_api::object_ptr<telegram_api::PhoneCallDiscardReason> &reason);

telegram_api::object_ptr<telegram_api::PhoneCallDiscardReason> get_input_phone_call_discard_reason(
    CallDiscardReason reason);

td_api::object_ptr<td_api::CallDiscardReason> get_call_discard_reason_object(CallDiscardReason reason);

bool operator==(const CallDiscardReason &lhs, const CallDiscardReason &rhs);

inline bool operator!=(const CallDiscardReason &lhs, const CallDiscardReason &rhs) {
  return !(lhs == rhs);
}

}  // namespace td
