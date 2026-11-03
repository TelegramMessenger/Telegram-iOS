//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

#include <type_traits>

namespace td {

class MessageTtl {
  int32 period_ = 0;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const MessageTtl &message_ttl);

  friend bool operator==(const MessageTtl &lhs, const MessageTtl &rhs);

 public:
  MessageTtl() = default;

  template <class T, typename = std::enable_if_t<std::is_convertible<T, int32>::value>>
  MessageTtl(T period) = delete;

  explicit MessageTtl(int32 period) : period_(period) {
  }

  bool is_empty() const;

  int32 get_message_auto_delete_time_object() const;

  int32 get_input_ttl_period() const;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(period_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(period_, parser);
  }
};

bool operator==(const MessageTtl &lhs, const MessageTtl &rhs);

inline bool operator!=(const MessageTtl &lhs, const MessageTtl &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageTtl &message_ttl);

}  // namespace td
