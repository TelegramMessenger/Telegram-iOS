//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageTtl.h"

namespace td {

bool MessageTtl::is_empty() const {
  return period_ == 0;
}

int32 MessageTtl::get_message_auto_delete_time_object() const {
  return period_;
}

int32 MessageTtl::get_input_ttl_period() const {
  return period_;
}

bool operator==(const MessageTtl &lhs, const MessageTtl &rhs) {
  return lhs.period_ == rhs.period_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageTtl &message_ttl) {
  return string_builder << "MessageTtl[" << message_ttl.period_ << "]";
}

}  // namespace td
