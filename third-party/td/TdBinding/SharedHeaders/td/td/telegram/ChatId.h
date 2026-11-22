//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/Version.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

#include <type_traits>

namespace td {

class ChatId {
  int64 id = 0;

 public:
  static constexpr int64 MAX_CHAT_ID = 999999999999ll;

  ChatId() = default;

  explicit constexpr ChatId(int64 chat_id) : id(chat_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int64>::value>>
  ChatId(T chat_id) = delete;

  bool is_valid() const {
    return 0 < id && id <= MAX_CHAT_ID;
  }

  int64 get() const {
    return id;
  }

  bool operator==(const ChatId &other) const {
    return id == other.id;
  }

  bool operator!=(const ChatId &other) const {
    return id != other.id;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_long(id);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    if (parser.version() >= static_cast<int32>(Version::Support64BitIds)) {
      id = parser.fetch_long();
    } else {
      id = parser.fetch_int();
    }
  }
};

struct ChatIdHash {
  uint32 operator()(ChatId chat_id) const {
    return Hash<int64>()(chat_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, ChatId chat_id) {
  return string_builder << "basic group " << chat_id.get();
}

}  // namespace td
