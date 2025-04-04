//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageContentType.h"
#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

#include <type_traits>

namespace td {

class MessageSelfDestructType {
  int32 ttl_ = 0;

  friend bool operator==(const MessageSelfDestructType &lhs, const MessageSelfDestructType &rhs);

 public:
  MessageSelfDestructType() = default;

  template <class T, typename = std::enable_if_t<std::is_convertible<T, int32>::value>>
  MessageSelfDestructType(T ttl) = delete;

  MessageSelfDestructType(int32 ttl, bool allow_immediate) : ttl_(ttl) {
    if (!allow_immediate && is_immediate()) {
      ttl_ = 0x7FFFFFFE;
    }
  }

  bool is_valid() const;

  bool is_empty() const;

  bool is_immediate() const;

  bool is_secret_message_content(MessageContentType content_type);

  void ensure_at_least(int32 ttl);

  static Result<MessageSelfDestructType> get_message_self_destruct_type(
      td_api::object_ptr<td_api::MessageSelfDestructType> &&self_destruct_type);

  td_api::object_ptr<td_api::MessageSelfDestructType> get_message_self_destruct_type_object() const;

  int32 get_input_ttl() const;

  template <class StorerT>
  void store(StorerT &storer) const {
    td::store(ttl_, storer);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    td::parse(ttl_, parser);
  }
};

bool operator==(const MessageSelfDestructType &lhs, const MessageSelfDestructType &rhs);

inline bool operator!=(const MessageSelfDestructType &lhs, const MessageSelfDestructType &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageSelfDestructType &message_self_destruct_type);

}  // namespace td
