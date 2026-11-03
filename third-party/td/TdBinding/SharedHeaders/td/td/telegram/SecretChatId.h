//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

#include <type_traits>

namespace td {

enum class SecretChatState : int32 { Unknown = -1, Waiting, Active, Closed };

class SecretChatId {
  int32 id = 0;

 public:
  SecretChatId() = default;

  explicit constexpr SecretChatId(int32 chat_id) : id(chat_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int32>::value>>
  SecretChatId(T chat_id) = delete;

  bool is_valid() const {
    return id != 0;
  }

  int32 get() const {
    return id;
  }

  bool operator==(const SecretChatId &other) const {
    return id == other.id;
  }

  bool operator!=(const SecretChatId &other) const {
    return id != other.id;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_int(id);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    id = parser.fetch_int();
  }
};

struct SecretChatIdHash {
  uint32 operator()(SecretChatId secret_chat_id) const {
    return Hash<int32>()(secret_chat_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, SecretChatId secret_chat_id) {
  return string_builder << "secret chat " << secret_chat_id.get();
}

}  // namespace td
